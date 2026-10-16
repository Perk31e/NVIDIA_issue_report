<#
  정적 GPU/vBIOS 정보 수집 (GPU-Z 대체, 관리자 불필요).
  사용: .\collect_gpu_static.ps1 [-OutFile <path>]
#>
param([string]$OutFile = ".\nvidia-smi_static.txt")
$smi = @("C:\Windows\System32\nvidia-smi.exe","C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe") |
        Where-Object { Test-Path $_ } | Select-Object -First 1
if(-not $smi){ $smi=(Get-Command nvidia-smi.exe -EA SilentlyContinue).Source }
if(-not $smi){ throw "nvidia-smi.exe 없음" }
"# nvidia-smi static ($(Get-Date -Format o))" | Out-File $OutFile -Encoding utf8
"## --query-gpu" | Out-File $OutFile -Append -Encoding utf8
(& $smi --query-gpu=name,vbios_version,driver_version,pci.bus_id,memory.total,serial,uuid,pstate,power.limit,power.default_limit,enforced.power.limit,temperature.gpu --format=csv) | Out-File $OutFile -Append -Encoding utf8
"`r`n## -q (full)" | Out-File $OutFile -Append -Encoding utf8
(& $smi -q) | Out-File $OutFile -Append -Encoding utf8
"저장: $OutFile"
& $smi --query-gpu=name,vbios_version,driver_version,memory.total --format=csv,noheader
