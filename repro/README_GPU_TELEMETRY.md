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
| `install_startup_nonadmin.ps1` | **관리자 불필요** 대안: 사용자 Startup 폴더에 숨김 .vbs를 넣어 로그온 시 자동 시작. 스케줄 작업(`install_gpu_logger_task.ps1`)과 **택1**로 사용. |

> 자동 시작 방식 택1 — ① `install_gpu_logger_task.ps1`(스케줄 작업, **등록에 관리자 권한 필요**) 또는 ② `install_startup_nonadmin.ps1`(Startup 폴더, 관리자 불필요). 둘을 동시에 켜면 로거가 중복 실행될 수 있으니 하나만.

## 사용
```powershell
# 1) 정적 정보 (제보 첨부용)
.\collect_gpu_static.ps1 -OutFile .\nvidia-smi_static.txt

# 2) 상시 로거 자동 시작 등록 (관리자 불필요)
.\install_gpu_logger_task.ps1
Start-ScheduledTask -TaskName NVIDIA_GPU_TDR_Telemetry   # 지금 즉시 시작
#   해제: .\install_gpu_logger_task.ps1 -Uninstall

# 로그 위치 (프로젝트 내, .gitignore 처리)
#   C:\NVIDIA_issue_report\telemetry_logs\gpu_telemetry_YYYYMMDD.csv  (21일 보존 후 자동 정리)
```

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
- `install_gpu_logger_task.ps1` → 관리자 없이 등록, 작업 State `Running`, `C:\ProgramData\EST_REM_GPU_TDR\`에 실제 로그 기록 확인.
- **현재 이 호스트에서 스케줄 작업이 등록·실행(활성) 상태** — 다음 TDR까지 자동 수집 중.

## 비고
- DDU 클린 설치 / 다른 드라이버 브랜치 테스트는 **NVIDIA가 요청하면** 진행(현 단계 미수행).
- 로그는 프로젝트 내 `telemetry_logs/`에 쌓이며 **`.gitignore`로 git 이력에서 제외**. 필요한 구간만 `nvidia_submission/`로 복사.
