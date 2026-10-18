# NVIDIA 제보용 서브셋 (GPU 관련만, 무관 SW 제외)

NVIDIA(및 OEM MSI)에 보낼 **GPU TDR/DPC 안정성 이슈** 패키지. 이 폴더의 텍스트 증거는 **GPU와 무관한 제3자 소프트웨어 항목을 제거/배제**했습니다.

## 증상 요약
- GPU: NVIDIA GeForce RTX 4060 Laptop GPU / vBIOS `95.07.16.40.ec` / 드라이버 `617.42`(32.0.16.1742)
- **0x116 VIDEO_TDR ×3** (2026-09-13 / 09-14 / 10-02): 동일 시그니처. GPU 타임아웃 후 `dxgkrnl` 어댑터 리셋이 `STATUS_INSUFFICIENT_RESOURCES(0xC000009A)`로 실패 → 복구 불가.
  `TdrBugcheckOnTimeout ← ADAPTER_RENDER::Reset ← TdrResetFromTimeout`
- **0x133 DPC_WATCHDOG** (2026-10-16): nvlddmkm DPC가 할당 시간 초과(`KiExecuteAllDpcs → nvlddmkm → RtlCaptureStackBackTrace`).
- 서로 다른 드라이버 버전(DriverStore inf 3종)에서 재발 → 업데이트로 미해소. TDR 레지스트리는 전부 기본값.

## 이 폴더에 포함 (텍스트, GPU 관련만)
- `nvidia-smi_static.txt` — vBIOS/드라이버/전력한계 등 GPU 정적 정보.
- `driver_bios_gpu.txt` — GPU/BIOS/OS 요약.
- `gpu_events_filtered.txt` — System 이벤트 중 **GPU/TDR 관련만** 필터(무관 bugcheck·타 드라이버 줄 제외).
- `SUBMISSION_EN.md` — NVIDIA 티켓/피드백 폼에 붙여 넣을 영문 본문 초안.
- `MANIFEST.txt` — 함께 첨부할 바이너리 덤프 목록(아래).

## 함께 첨부할 덤프 (바이너리, 상위 폴더 참조)
`MANIFEST.txt` 참조. 덤프는 커널 미니덤프라 **로드된 전체 드라이버 목록**이 들어있는 것이 정상입니다(모든 커널 덤프 공통). 무관 제3자 SW 미적재 상태의 증거를 원하면 **09-13·09-14 TDR 덤프**만으로도 동일 버그가 재현되어 있습니다.

## 라이브 텔레메트리(선택)
`../repro/`의 상시 로거가 다음 TDR 직전 상태를 `C:\ProgramData\EST_REM_GPU_TDR\`에 남깁니다. TDR 발생 후 해당 구간 CSV를 이 폴더에 추가해 제출하면 원인 분석에 큰 도움.

## 미수행(요청 시 진행)
- DDU 클린 설치 + 다른 드라이버 브랜치 롤백 테스트 — NVIDIA가 요청하면 진행.
