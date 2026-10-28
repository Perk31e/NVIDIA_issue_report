<#
  포맷 전 증거 백업. 원본은 지우거나 옮기지 않고 "복사"만 해서 zip 하나로 묶음.
  관리자 PowerShell에서 실행 (C:\Windows\Minidump, LiveKernelReports 읽기에 필요):
    powershell -ExecutionPolicy Bypass -File .\backup_before_format.ps1 -Destination D:\
  -Destination 은 포맷되지 않는 곳(USB/외장디스크/D:)으로. 기본값(바탕화면)은 C:라서 포맷 시 같이 지워짐.
  묶는 것:
    C:\Windows\Minidump\*                  (0x116/0x133 미니덤프)
    C:\Windows\LiveKernelReports\**         (WATCHDOG 0x141, 0x1A8/0x1B8 라이브 덤프)
    C:\Coding_Practice\nvidia_20261028\**   (10-28 사본 + cdb 출력)
    C:\NVIDIA_issue_report\telemetry_logs\  (있으면)
    System / Application 이벤트 로그(.evtx) - 포맷하면 사라지므로 같이 내보냄
    -IncludeMemoryDmp 지정 시 C:\Windows\MEMORY.DMP (수 GB)
  zip 안에 MANIFEST.txt (원본 경로, 크기, SHA256) 포함. 끝에 zip 안 파일 수를 원본과 대조.
#>
param(
  [string]$Destination = [Environment]::GetFolderPath('Desktop'),
  [switch]$IncludeMemoryDmp
)
$ErrorActionPreference = 'Stop'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if(-not $isAdmin){ throw "관리자 PowerShell에서 실행하세요 (Minidump / LiveKernelReports 읽기 권한 필요)." }

$sources = [ordered]@{
  'Minidump'          = 'C:\Windows\Minidump'
  'LiveKernelReports' = 'C:\Windows\LiveKernelReports'
  'nvidia_20261028'   = 'C:\Coding_Practice\nvidia_20261028'
  'telemetry_logs'    = 'C:\NVIDIA_issue_report\telemetry_logs'
}
$stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$staging = Join-Path $env:TEMP "nvidia_backup_$stamp"
$zip     = Join-Path $Destination "nvidia_evidence_backup_$stamp.zip"
New-Item -ItemType Directory -Force $staging, $Destination | Out-Null

# 1) 복사 (원본은 읽기만). robocopy는 잠긴 파일도 /B(백업 모드)로 읽을 수 있음.
foreach($k in $sources.Keys){
  $src = $sources[$k]
  if(-not (Test-Path -LiteralPath $src)){ Write-Warning "없음, 건너뜀: $src"; continue }
  robocopy $src (Join-Path $staging $k) /E /B /COPY:DT /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
  if($LASTEXITCODE -ge 8){ Write-Warning "robocopy 일부 실패($LASTEXITCODE): $src" }
}
if($IncludeMemoryDmp){
  if(Test-Path 'C:\Windows\MEMORY.DMP'){
    New-Item -ItemType Directory -Force (Join-Path $staging 'MEMORY') | Out-Null
    robocopy 'C:\Windows' (Join-Path $staging 'MEMORY') MEMORY.DMP /B /COPY:DT /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
  } else { Write-Warning "MEMORY.DMP 없음" }
}

# 2) 이벤트 로그 내보내기
$ev = Join-Path $staging 'eventlogs'
New-Item -ItemType Directory -Force $ev | Out-Null
foreach($log in 'System','Application'){ wevtutil epl $log (Join-Path $ev "$log.evtx") }

# 3) 매니페스트 (원본 경로 기준)
$files = Get-ChildItem -LiteralPath $staging -Recurse -File
$manifest = Join-Path $staging 'MANIFEST.txt'
@("# nvidia evidence backup $(Get-Date -Format o) on $env:COMPUTERNAME", "# relative_path`tbytes`tsha256`tlast_write") |
  Set-Content -LiteralPath $manifest -Encoding utf8
foreach($f in $files){
  $rel = $f.FullName.Substring($staging.Length + 1)
  "{0}`t{1}`t{2}`t{3:o}" -f $rel, $f.Length, (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash, $f.LastWriteTime |
    Add-Content -LiteralPath $manifest -Encoding utf8
}

# 4) zip (ZipFile은 2GB 이상 파일도 처리, Compress-Archive보다 안전)
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($staging, $zip, [System.IO.Compression.CompressionLevel]::Optimal, $false)

# 5) 검증: zip 안 파일 수 = 스테이징 파일 수(+MANIFEST)
$z = [System.IO.Compression.ZipFile]::OpenRead($zip)
$inZip = @($z.Entries | Where-Object { $_.Name }).Count
$z.Dispose()
$expected = $files.Count + 1
Remove-Item -LiteralPath $staging -Recurse -Force   # 임시 사본만 삭제, 원본은 그대로

""
foreach($k in $sources.Keys){
  $n = @($files | Where-Object { $_.FullName -like (Join-Path $staging "$k\*") }).Count
  "{0,-18} {1,4} 파일   ({2})" -f $k, $n, $sources[$k]
}
"zip: $zip  ($([math]::Round((Get-Item $zip).Length/1MB,1)) MB, $inZip/$expected 파일)"
if($inZip -ne $expected){ Write-Warning "zip 파일 수 불일치 - 다시 실행하세요"; exit 1 }
if($zip.StartsWith('C:', 'OrdinalIgnoreCase')){ Write-Warning "zip이 C: 드라이브에 있음. 포맷 전에 USB/클라우드로 옮기세요!" }
"원본은 삭제하지 않았습니다."
