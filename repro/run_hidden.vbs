' gpu_telemetry_logger.ps1 을 "콘솔 창 없이" 백그라운드로 실행하는 런처.
' wscript가 Run(...,0,False)로 호출 → powershell 콘솔 창이 전혀 뜨지 않음. 사용자 세션에서 실행되어 워크로드 맥락(포그라운드/GPU점유/디스플레이)도 정상 수집.
Dim sh, fso, dir, cmd
Set sh  = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & dir & "\gpu_telemetry_logger.ps1"""
' 두 번째 인자 0 = 창 숨김.
' 세 번째 True = powershell 종료까지 대기 → 작업 스케줄러가 wscript를 "실행 중"으로 유지하여
'   프로세스 트리(=로거)를 종료시키지 않음. (False로 두면 wscript 즉시 종료 → TS가 로거까지 정리)
sh.Run cmd, 0, True
