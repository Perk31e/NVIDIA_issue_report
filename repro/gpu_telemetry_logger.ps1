<#
  GPU TDR 상시 텔레메트리 + 워크로드 로거
  목적: NVIDIA 0x116 TDR / 0x133 재발 시, "행(hang) 직전"의 온도/전력/클럭/VRAM/스로틀과
        당시 워크로드(AC·포그라운드앱·GPU 점유 상위 프로세스·디스플레이 수)를 자동 기록.
  설계: nvidia-smi 기반(관리자 불필요). 매 샘플을 즉시 flush하여 하드 크래쉬/BSOD에도 직전 샘플 보존.
  사용: 그냥 실행하면 포그라운드 로깅. 상시 수집은 install_gpu_logger_task.ps1로 로그온 시 자동 실행 등록.
#>
param(
  [string]$OutDir = "C:\ProgramData\EST_REM_GPU_TDR",
  [int]$IntervalSec = 5,
  [int]$RetentionDays = 21
)
$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force $OutDir | Out-Null

$smi = @("C:\Windows\System32\nvidia-smi.exe","C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe") |
        Where-Object { Test-Path $_ } | Select-Object -First 1
if(-not $smi){ $smi = (Get-Command nvidia-smi.exe -EA SilentlyContinue).Source }
if(-not $smi){ throw "nvidia-smi.exe를 찾을 수 없음" }

# 포그라운드 프로세스 식별용 Win32
Add-Type -Namespace Win32 -Name FG -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(IntPtr h, out int pid);
'@ -ErrorAction SilentlyContinue

function Get-Foreground {
  try { $h=[Win32.FG]::GetForegroundWindow(); $p=0; [void][Win32.FG]::GetWindowThreadProcessId($h,[ref]$p)
        (Get-Process -Id $p -EA Stop).ProcessName } catch { "?" }
}
function Get-TopGpuProcs {
  try {
    $s = (Get-Counter '\GPU Engine(*)\Utilization Percentage' -EA Stop).CounterSamples | Where-Object { $_.CookedValue -gt 1 }
    $byPid = @{}
    foreach($x in $s){ if($x.InstanceName -match 'pid_(\d+)_'){ $pidn=[int]$Matches[1]; $byPid[$pidn]=[double]$byPid[$pidn]+$x.CookedValue } }
    ($byPid.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 3 | ForEach-Object {
        $nm=try{(Get-Process -Id $_.Key -EA Stop).ProcessName}catch{"pid$($_.Key)"}; "$nm=$([math]::Round($_.Value))%"
    }) -join ' '
  } catch { "" }
}
function Get-AC {
  try { Add-Type -Namespace Win32 -Name PW -MemberDefinition @'
[StructLayout(LayoutKind.Sequential)] public struct SPS { public byte AC; public byte Flag; public byte Pct; public byte Rsv; public int Life; public int Full; }
[DllImport("kernel32.dll")] public static extern bool GetSystemPowerStatus(out SPS s);
'@ -EA SilentlyContinue
        $st=New-Object Win32.PW+SPS; [void][Win32.PW]::GetSystemPowerStatus([ref]$st)
        if($st.AC -eq 1){"AC"}elseif($st.AC -eq 0){"BAT"}else{"?"} } catch { "?" }
}
function Get-DisplayCount { try { Add-Type -AssemblyName System.Windows.Forms -EA SilentlyContinue; [System.Windows.Forms.Screen]::AllScreens.Count } catch { "?" } }

$q = 'temperature.gpu,utilization.gpu,utilization.memory,memory.used,memory.total,power.draw,enforced.power.limit,' +
     'clocks.current.sm,clocks.current.memory,pstate,clocks_event_reasons.active,' +
     'clocks_event_reasons.hw_thermal_slowdown,clocks_event_reasons.sw_power_cap,clocks_event_reasons.hw_power_brake_slowdown'
$header = "iso_time,temp_c,gpu_util,mem_util,mem_used_mib,mem_total_mib,power_w,power_limit_w,sm_mhz,mem_mhz,pstate," +
          "throttle_active,hw_thermal,sw_power_cap,hw_power_brake,ac,displays,foreground,top_gpu_procs"

Write-Host "[logger] nvidia-smi=$smi interval=${IntervalSec}s out=$OutDir"
while($true){
  $now = Get-Date
  $file = Join-Path $OutDir ("gpu_telemetry_{0:yyyyMMdd}.csv" -f $now)
  if(-not (Test-Path $file)){ Add-Content -LiteralPath $file -Value $header -Encoding utf8
    # 보존기간 지난 로그 정리
    Get-ChildItem $OutDir -Filter 'gpu_telemetry_*.csv' -EA SilentlyContinue | Where-Object { $_.LastWriteTime -lt $now.AddDays(-$RetentionDays) } | Remove-Item -Force -EA SilentlyContinue
  }
  $g = (& $smi --query-gpu=$q --format=csv,noheader,nounits 2>$null)
  if($g){ $g = ($g -replace '\s*,\s*',',').Trim() }
  $line = "{0},{1},{2},{3},{4},{5}" -f $now.ToString('o'), $g, (Get-AC), (Get-DisplayCount), (Get-Foreground), (Get-TopGpuProcs)
  try { Add-Content -LiteralPath $file -Value $line -Encoding utf8 } catch {}
  Start-Sleep -Seconds $IntervalSec
}
