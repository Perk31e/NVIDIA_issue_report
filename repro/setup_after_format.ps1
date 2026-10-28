<#
  포맷(클린 설치) 직후 1회 실행하는 원클릭 설정.
  관리자 PowerShell에서, NVIDIA 드라이버 설치 후 실행:
    powershell -ExecutionPolicy Bypass -File .\setup_after_format.ps1
  옵션:
    -DumpType Kernel|Active|Complete   커널 크래시 덤프 종류 (기본 Kernel)
    -SkipCrashDump                     덤프 설정은 건드리지 않음
    -VerifySeconds 30                  로거가 CSV에 쓰는지 기다리는 최대 시간
  하는 일:
    1) 이전 이름(EST_REM_GPU_TDR_Telemetry) 작업과 Startup 폴더 방식 제거 (중복 실행 방지)
    2) install_gpu_logger_task.ps1 로 스케줄 작업 등록 후 즉시 시작
    3) 작업이 Running 이고 오늘자 CSV에 새 행이 쌓이는지 확인
    4) 크래시 덤프를 커널/전체 메모리 덤프 + 미니덤프 보존으로 설정
  끝에 PASS/FAIL 요약을 출력하고, 하나라도 FAIL이면 종료 코드 1.
#>
param(
  [ValidateSet('Kernel','Active','Complete')][string]$DumpType = 'Kernel',
  [switch]$SkipCrashDump,
  [int]$VerifySeconds = 30
)
$ErrorActionPreference = 'Stop'
$TaskName   = "NVIDIA_GPU_TDR_Telemetry"
$LegacyTask = "EST_REM_GPU_TDR_Telemetry"
$LogDir     = "C:\NVIDIA_issue_report\telemetry_logs"   # gpu_telemetry_logger.ps1 기본값과 동일해야 함
$results    = [System.Collections.Generic.List[object]]::new()
function Add-Result($name, $ok, $detail){ $results.Add([pscustomobject]@{ Check=$name; Result=$(if($ok){'PASS'}else{'FAIL'}); Detail=$detail }) }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if(-not $isAdmin){ throw "관리자 PowerShell에서 실행하세요 (작업 등록·덤프 설정에 필요)." }

# 0) 인터넷에서 받은 zip이면 차단 표시(MOTW) 해제
Get-ChildItem -LiteralPath $PSScriptRoot -File | Unblock-File -EA SilentlyContinue

# 1) nvidia-smi 확인 (드라이버 미설치면 로거가 바로 죽음)
$smi = @("C:\Windows\System32\nvidia-smi.exe","C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe") |
        Where-Object { Test-Path $_ } | Select-Object -First 1
if($smi){
  $drv = (& $smi --query-gpu=name,driver_version,vbios_version --format=csv,noheader 2>$null) -join '; '
  Add-Result "nvidia-smi" $true $drv
} else {
  Add-Result "nvidia-smi" $false "없음 - NVIDIA 드라이버를 먼저 설치하고 다시 실행"
}

# 2) 중복 실행 방지: 예전 이름의 작업 / Startup 폴더 방식 제거
foreach($t in @($LegacyTask)){
  if(Get-ScheduledTask -TaskName $t -EA SilentlyContinue){
    Stop-ScheduledTask -TaskName $t -EA SilentlyContinue
    Unregister-ScheduledTask -TaskName $t -Confirm:$false
    Write-Host "예전 작업 제거: $t"
  }
}
$startupVbs = Join-Path ([Environment]::GetFolderPath('Startup')) "NVIDIA_GPU_TDR_Telemetry.vbs"
if(Test-Path $startupVbs){ Remove-Item -LiteralPath $startupVbs -Force; Write-Host "Startup 방식 제거: $startupVbs" }

# 3) 작업 등록 + 시작
& (Join-Path $PSScriptRoot "install_gpu_logger_task.ps1") | Out-Host
$task = Get-ScheduledTask -TaskName $TaskName -EA SilentlyContinue
if(-not $task){
  Add-Result "작업 등록" $false "$TaskName 이 등록되지 않음"
} else {
  $act = ($task.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join ' | '
  Add-Result "작업 등록" $true "$TaskName ($($task.Principal.UserId), 로그온 시) -> $act"
  if($task.State -ne 'Running'){ Start-ScheduledTask -TaskName $TaskName }
}

# 4) 실제로 돌면서 CSV를 쓰는지 확인
if($task -and $smi){
  $csv = Join-Path $LogDir ("gpu_telemetry_{0:yyyyMMdd}.csv" -f (Get-Date))
  $before = if(Test-Path $csv){ @(Get-Content -LiteralPath $csv).Count } else { 0 }
  $deadline = (Get-Date).AddSeconds($VerifySeconds)
  $after = $before
  do {
    Start-Sleep -Seconds 3
    if(Test-Path $csv){ $after = @(Get-Content -LiteralPath $csv).Count }
  } while($after -le ($before + 1) -and (Get-Date) -lt $deadline)
  $state = (Get-ScheduledTask -TaskName $TaskName).State
  Add-Result "작업 상태" ($state -eq 'Running') "State=$state"
  $wrote = $after -gt ($before + 1)   # 새 파일이면 헤더+1행 이상, 기존 파일이면 2행 이상 증가
  $last  = if(Test-Path $csv){ Get-Content -LiteralPath $csv -Tail 1 } else { "(파일 없음)" }
  Add-Result "CSV 기록" $wrote "$csv : $before -> $after 행. 마지막: $last"
  $procs = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*gpu_telemetry_logger.ps1*' })
  Add-Result "로거 프로세스 1개" ($procs.Count -eq 1) "실행 중 $($procs.Count)개 (2개 이상이면 중복)"
}

# 5) 크래시 덤프 설정
#   CrashDumpEnabled: 1=전체(Complete), 2=커널, 1+FilterPages=1 = 활성(Active) 메모리 덤프
if(-not $SkipCrashDump){
  $cc = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"
  $mode = @{ Complete = 1; Kernel = 2; Active = 1 }[$DumpType]
  Set-ItemProperty $cc -Name CrashDumpEnabled    -Value $mode -Type DWord
  if($DumpType -eq 'Active'){ Set-ItemProperty $cc -Name FilterPages -Value 1 -Type DWord }
  else { Remove-ItemProperty $cc -Name FilterPages -EA SilentlyContinue }
  Set-ItemProperty $cc -Name DumpFile            -Value '%SystemRoot%\MEMORY.DMP' -Type ExpandString
  Set-ItemProperty $cc -Name MinidumpDir         -Value '%SystemRoot%\Minidump'  -Type ExpandString
  Set-ItemProperty $cc -Name Overwrite           -Value 1 -Type DWord
  Set-ItemProperty $cc -Name AlwaysKeepMemoryDump -Value 1 -Type DWord   # 디스크 여유가 적어도 MEMORY.DMP 삭제 안 함
  Set-ItemProperty $cc -Name LogEvent            -Value 1 -Type DWord
  Set-ItemProperty $cc -Name AutoReboot          -Value 1 -Type DWord
  $cs = Get-CimInstance Win32_ComputerSystem
  $pfOk = $cs.AutomaticManagedPagefile
  $ramGB = [math]::Round($cs.TotalPhysicalMemory/1GB)
  $v = Get-ItemProperty $cc
  Add-Result "크래시 덤프" ($v.CrashDumpEnabled -eq $mode) "$DumpType (CrashDumpEnabled=$($v.CrashDumpEnabled), FilterPages=$($v.FilterPages)), 재부팅 후 적용"
  Add-Result "페이지 파일" $pfOk $(if($pfOk){"시스템 관리 (RAM ${ramGB}GB)"}else{"수동 설정됨 - 덤프가 안 남을 수 있음. 시스템 관리 크기로 바꾸세요"})
}

# 요약
""
$results | Format-Table -AutoSize -Wrap | Out-Host
"로그 위치: $LogDir"
"다음 단계: 재부팅 1회 후 '.\setup_after_format.ps1 -SkipCrashDump' 를 다시 돌려 로그온 자동 시작까지 확인."
if($results | Where-Object Result -eq 'FAIL'){ exit 1 }
