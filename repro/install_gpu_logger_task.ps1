<#
  gpu_telemetry_logger.ps1 를 "로그온 시 자동 실행" 스케줄 작업으로 등록/해제.
  관리자 PowerShell에서 실행.
    등록:  .\install_gpu_logger_task.ps1
    해제:  .\install_gpu_logger_task.ps1 -Uninstall
  TDR은 사용 중(로그온 상태)에 발생하므로 AtLogOn + 최고권한 + 실패 시 재시작으로 구성.
  로그는 C:\NVIDIA_issue_report\telemetry_logs\gpu_telemetry_YYYYMMDD.csv 에 누적(.gitignore 처리).
#>
param([switch]$Uninstall)
$TaskName = "NVIDIA_GPU_TDR_Telemetry"
$logger = Join-Path $PSScriptRoot "gpu_telemetry_logger.ps1"
$vbs    = Join-Path $PSScriptRoot "run_hidden.vbs"

if($Uninstall){
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -EA SilentlyContinue
  "해제됨: $TaskName"; return
}
if(-not (Test-Path $logger)){ throw "로거 스크립트 없음: $logger" }
if(-not (Test-Path $vbs)){ throw "숨김 런처 없음: $vbs" }

# wscript + run_hidden.vbs 로 실행 → 콘솔 창이 전혀 뜨지 않음(완전 백그라운드).
$action  = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$vbs`""
$trigger = New-ScheduledTaskTrigger -AtLogOn
$set     = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
            -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
            -ExecutionTimeLimit ([TimeSpan]::Zero)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $set -Principal $principal -Force | Out-Null
"등록됨: $TaskName (다음 로그온부터 자동 시작)"
"지금 바로 시작하려면: Start-ScheduledTask -TaskName $TaskName"
"로그 위치: C:\NVIDIA_issue_report\telemetry_logs\ (.gitignore)"
