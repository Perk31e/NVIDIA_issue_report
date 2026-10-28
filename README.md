# NVIDIA `nvlddmkm.sys` GPU 안정성 이슈 제보

NVIDIA(및 노트북 OEM MSI)에 보낼 **GPU 드라이버 안정성 문제** 제보 자료를 모아 둔 리포지토리입니다.

**이건 보안 취약점(제로데이) 제보가 아닙니다.** 공격자가 조종할 수 있는 지점이 없고, 영향은 블루스크린/재부팅(가용성)뿐입니다. 그래서 제로데이 연구 리포에서 분리했습니다.

## 무슨 문제인가

- 장비: MSI Creator Z17HX (호스트 L4B_D0G), NVIDIA GeForce RTX 4060 Laptop GPU + Intel UHD 하이브리드, Windows 11 26100
- 드라이버: `nvlddmkm.sys` 32.0.16.1742 (공개판 617.42 계열)
- **0x116 VIDEO_TDR_FAILURE 3건** (2026-09-13, 09-14, 10-02): GPU가 시간 안에 응답하지 않아 Windows가 GPU를 리셋하려 했는데, 그 리셋 자체가 `0xC000009A`(자원 부족)로 실패해서 블루스크린. 3건 모두 스택과 인자가 똑같고, 드라이버 버전을 바꿔도 재발.
- **0x133 DPC_WATCHDOG_VIOLATION 1건** (2026-10-16): NVIDIA 드라이버의 DPC(커널 지연 작업)가 허용 시간을 넘김.

자세한 분석은 [`REPORT.md`](REPORT.md), 제출용 묶음 설명은 [`nvidia_submission/README_SUBMISSION.md`](nvidia_submission/README_SUBMISSION.md)를 보세요.

## 폴더 구성

| 경로 | 내용 |
|---|---|
| `REPORT.md` | 전체 분석 보고서 |
| `SOURCE.txt` | 덤프 원본 위치, 장비, 드라이버 해시 |
| `analysis/` | 덤프 분석 메모 |
| `dumps/` | 커널 미니덤프 4개 (0x116 ×3, 0x133 ×1) |
| `livekernelreports/` | 같은 날짜 TDR의 GPU 워치독 라이브 캡처 3개 |
| `evidence/` | DxDiag, msinfo32, 이벤트 로그, nvidia-smi 등 호스트 증거 |
| `binaries/` | 드라이버 버전/해시 (108MB 원본 바이너리는 미포함) |
| `nvidia_submission/` | NVIDIA에 실제로 보낼 GPU 관련 자료만 추린 서브셋 |
| `repro/` | 다음 TDR 직전 상태를 남기는 GPU 텔레메트리 수집 스크립트. 포맷 전 백업/포맷 후 설정 절차는 [`repro/README_GPU_TELEMETRY.md`](repro/README_GPU_TELEMETRY.md#포맷클린-설치-절차) |

## 상태

- 제출 패키지 준비 완료, **아직 NVIDIA에 보내지 않음** (2026-10-18 기준).
- 이후 작업은 Claude 프로젝트 "NVIDIA 제보"에서 진행합니다.

## 이전 기록

원래 [`Perk31e/EST_REM_BB_Target`](https://github.com/Perk31e/EST_REM_BB_Target)의 `EST_REM_12_NVIDIA_nvlddmkm/` 폴더였습니다. 2026-10-18에 `git subtree split`으로 커밋 기록(5개)을 그대로 살려 이 리포 최상위로 옮겼습니다. 이전 직전 원본 커밋은 `cb7c9db`입니다.
