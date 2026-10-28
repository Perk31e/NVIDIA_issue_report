# GPU TDR 자동 수집 도구 (NVIDIA 제보 보강)

"재현 조건/워크로드" + "부하 중 GPU 텔레메트리"를 **상시 자동**으로 남겨, 다음 0x116 TDR / 0x133 발생 시
행(hang) 직전 상태를 확보하기 위한 도구. 모두 `nvidia-smi` 기반 — **GPU-Z 수동 불필요, 관리자 권한 불필요**.

## 스크립트
| 파일 | 역할 |
|---|---|
| `collect_gpu_static.ps1` | 정적 정보 1회 수집(vBIOS/GPU/드라이버/전력한계 등). GPU-Z 대체. |
| `gpu_telemetry_logger.ps1` | 상시 로거: 매 5초 온도/util/VRAM/전력/클럭/pstate/스로틀 + AC·포그라운드앱·GPU점유 상위·디스플레이 수 → CSV(매 샘플 flush). |
| `install_gpu_logger_task.ps1` | 로거를 "로그온 시 자동 실행" 스케줄 작업으로 등록/해제. |
| `run_hidden.vbs` | 콘솔 창 없이(완전 백그라운드) 로거를 실행하는 런처. 스케줄 작업이 이 vbs를 호출(wscript)해 **터미널 창이 뜨지 않음**. wscript가 powershell 종료까지 대기해 작업 스케줄러가 프로세스 트리를 유지. |
| `setup_after_format.ps1` | **포맷 후 원클릭 설정**(관리자): 작업 등록·시작 + 실행/CSV 기록 검증 + 크래시 덤프 설정. 아래 "포맷 절차" 참고. |
| `backup_before_format.ps1` | **포맷 전 백업**(관리자): 덤프·라이브 덤프·이벤트 로그를 zip 하나로 복사(원본 유지). |
| `install_startup_nonadmin.ps1` | **관리자 불필요** 대안: 사용자 Startup 폴더에 숨김 .vbs를 넣어 로그온 시 자동 시작. 스케줄 작업(`install_gpu_logger_task.ps1`)과 **택1**로 사용. |

> 자동 시작 방식 택1 — ① `install_gpu_logger_task.ps1`(스케줄 작업, **등록에 관리자 권한 필요**) 또는 ② `install_startup_nonadmin.ps1`(Startup 폴더, 관리자 불필요). 둘을 동시에 켜면 로거가 중복 실행될 수 있으니 하나만.

## 사용
```powershell
# 1) 정적 정보 (제보 첨부용)
.\collect_gpu_static.ps1 -OutFile .\nvidia-smi_static.txt

# 2) 상시 로거 자동 시작 등록 (관리자 PowerShell)
.\install_gpu_logger_task.ps1
Start-ScheduledTask -TaskName NVIDIA_GPU_TDR_Telemetry   # 지금 즉시 시작
#   해제: .\install_gpu_logger_task.ps1 -Uninstall

# 로그 위치 (프로젝트 내, .gitignore 처리)
#   C:\NVIDIA_issue_report\telemetry_logs\gpu_telemetry_YYYYMMDD.csv  (21일 보존 후 자동 정리)
```

## 포맷(클린 설치) 절차

**포맷 전** (관리자 PowerShell, 이 `repro/` 폴더에서):
```powershell
powershell -ExecutionPolicy Bypass -File .\backup_before_format.ps1 -Destination D:\   # USB/외장 드라이브 경로로
```
`C:\Windows\Minidump`, `C:\Windows\LiveKernelReports`, `C:\Coding_Practice\nvidia_20261028`, 텔레메트리 로그, System/Application 이벤트 로그를
`nvidia_evidence_backup_<시각>.zip` 하나로 묶습니다(MANIFEST.txt에 SHA256 포함). **원본은 지우지 않습니다.**
`-Destination`을 안 주면 바탕화면(C:)에 생기므로, 포맷 전에 꼭 다른 드라이브로 옮기세요. 전체 메모리 덤프까지 원하면 `-IncludeMemoryDmp`.

**포맷 후**:
1. Windows 업데이트 → NVIDIA 드라이버 설치 (Afterburner 등 튜닝 도구는 설치하지 않음).
2. 이 리포를 `C:\NVIDIA_issue_report`에 받기 (git clone 또는 GitHub에서 zip 다운로드 후 압축 해제).
3. 관리자 PowerShell:
   ```powershell
   cd C:\NVIDIA_issue_report\repro
   powershell -ExecutionPolicy Bypass -File .\setup_after_format.ps1
   ```
   스케줄 작업 등록·시작, 작업 `Running` 여부, 오늘자 CSV에 새 행이 쌓이는지, 로거 프로세스 중복 여부, 유휴(P8) GPU 온도가 70C를 넘는지(넘으면 WARN)를 확인하고
   크래시 덤프를 **커널 메모리 덤프**로 설정합니다(`-DumpType Active` 또는 `Complete`로 변경 가능). 마지막에 PASS/FAIL 표가 나옵니다.
4. 재부팅 후 한 번 더 `.\setup_after_format.ps1 -SkipCrashDump` → 로그온 자동 시작까지 PASS면 끝.

## TDR 발생 후 수확(harvest)
1. 크래쉬 시각 확인(이벤트뷰어 또는 `C:\Windows\Minidump`의 새 덤프).
2. `telemetry_logs/gpu_telemetry_YYYYMMDD.csv`에서 **크래쉬 직전 수십 초** 구간을 잘라 `../nvidia_submission/`에 복사.
3. 새 미니덤프/전체덤프도 `../dumps/`에 추가. → 제보 패키지 갱신.

## CSV 컬럼
`iso_time, temp_c, gpu_util, mem_util, mem_used_mib, mem_total_mib, power_w, power_limit_w, sm_mhz, mem_mhz, pstate, throttle_active, hw_thermal, sw_power_cap, hw_power_brake, ac, displays, foreground, top_gpu_procs`

## 검증 결과 (이 호스트 L4B_D0G, 2026-10-16)
3개 스크립트 실제 실행으로 동작 확인:
- `collect_gpu_static.ps1` → vBIOS `95.07.16.40.ec`, 드라이버 617.42, RTX 4060 Laptop 8188MiB 정상 추출.
- `gpu_telemetry_logger.ps1` → CSV 전 컬럼 실값 기록 확인. 예:
  ```
  2026-10-16T19:37:03,76,9,2,1108,8188,18.32,85.95,1920,8001,P0,0x...,Not Active,Not Active,Not Active,AC,2,claude,dwm=31% msedge=8%
  ```
- `install_gpu_logger_task.ps1` → 작업 State `Running`, 실제 로그 기록 확인 (당시 이름 `EST_REM_GPU_TDR_Telemetry`, 경로 `C:\ProgramData\EST_REM_GPU_TDR\`).
- **2026-10-28 확인 시 작업이 등록되어 있지 않았고 로그도 비어 있었음** (이름 변경 후 재등록 누락으로 추정). 그래서 포맷 후에는 `setup_after_format.ps1`로 등록과 동작을 함께 검증함.

## 비고
- DDU 클린 설치 / 다른 드라이버 브랜치 테스트는 **NVIDIA가 요청하면** 진행(현 단계 미수행).
- 로그는 프로젝트 내 `telemetry_logs/`에 쌓이며 **`.gitignore`로 git 이력에서 제외**. 필요한 구간만 `nvidia_submission/`로 복사.
