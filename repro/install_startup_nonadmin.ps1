<#
  관리자 권한 없이 "로그온 시 자동 시작"을 설정하는 대안.
  사용자 Startup 폴더에 숨김 런처 .vbs를 넣어, 로그온 시 콘솔 창 없이 로거를 자동 실행.
  (스케줄 작업 등록에 관리자 권한이 필요한 환경에서 사용. 스케줄 작업 방식과 '둘 중 하나만' 쓸 것.)
    설치:  .\install_startup_nonadmin.ps1
    해제:  .\install_startup_nonadmin.ps1 -Uninstall
#>
param([switch]$Uninstall)
$startup = [Environment]::GetFolderPath('Startup')
$dst    = Join-Path $startup "NVIDIA_GPU_TDR_Telemetry.vbs"
$logger = Join-Path $PSScriptRoot "gpu_telemetry_logger.ps1"

if($Uninstall){ Remove-Item -LiteralPath $dst -Force -EA SilentlyContinue; "removed: $dst"; return }
if(-not (Test-Path $logger)){ throw "logger not found: $logger" }

# ASCII-only VBS (인코딩 문제 회피). Run(...,0,True): 창 숨김 + powershell 종료까지 대기.
$vbs = @"
' Auto-start GPU telemetry logger at logon, hidden (no admin required).
Set sh = CreateObject("WScript.Shell")
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$logger""", 0, True
"@
Set-Content -LiteralPath $dst -Value $vbs -Encoding Ascii
"installed: $dst"
"logon 시 자동 실행(숨김). 지금 수동 시작: wscript.exe `"$dst`""
