# NVIDIA `nvlddmkm.sys` — GPU TDR(0x116) ×3 + DPC watchdog(0x133)

**성격: 보안 취약점(제보)이 아니라 GPU 드라이버 안정성/신뢰성 결함.** 공격자 제어 프리미티브가 없고 임팩트는 재부팅/BSOD(가용성). 벤더: **NVIDIA** (디바이스: GeForce RTX 4060 Laptop GPU). 호스트 L4B_D0G(MSI Creator Z17HX, Win11 26100, Intel UHD + NVIDIA 하이브리드).

- `nvlddmkm.sys` **32.0.16.1742** (2026-10-02, 108.7MB, SHA256 `DB407B96…F84B`; NVIDIA 공개판 ≈ 617.42 계열)
- TDR 레지스트리(TdrLevel/Delay/DdiDelay): **전부 기본값**(사용자 수정 없음)

## 1. 사건 목록 (dumps/)

| 파일 | 일시 | Bugcheck | Uptime | 비고 |
|---|---|---|---|---|
| `tdr_091326-17828-01_0x116.dmp` | 09-13 13:38 | 0x116 VIDEO_TDR_FAILURE | 3h16m | 리셋 실패 c000009a |
| `tdr_091426-19140-01_0x116.dmp` | 09-14 23:49 | 0x116 | 16h02m | 동일 시그니처 |
| `tdr_100226-21437-01_0x116.dmp` | 10-02 14:21 | 0x116 | 22h21m | 동일 시그니처 |
| `dpcwatchdog_101626-20234-01_0x133.dmp` | 10-16 13:40 | 0x133 DPC_WATCHDOG_VIOLATION | 19m | NVIDIA DPC 초과 |

보강: `livekernelreports/WATCHDOG-*.dmp` 3개 = 같은 날짜 TDR의 GPU 워치독 라이브 캡처.
전체덤프 `C:\Windows\MEMORY.dmp`(16GB)는 0x133과 동일 사건이나 대용량·독점 심볼 없음으로 **미포함**(아래 §4 참고).

## 2. 0x116 VIDEO_TDR_FAILURE — 3건 **동일 실패 경로** (심화)

세 덤프 모두 인자·스택이 동일:
```
Arg1 = TDR_RECOVERY_CONTEXT 포인터
Arg2 = 책임 모듈(owner tag) → nvlddmkm
Arg3 = 0xC000009A  (STATUS_INSUFFICIENT_RESOURCES)   ← 리셋이 반환한 실패 코드
Arg4 = 4
STACK:
  dxgkrnl!TdrBugcheckOnTimeout
  dxgkrnl!ADAPTER_RENDER::Reset+0x12d
  dxgkrnl!DXGADAPTER::Reset+0x58a
  dxgkrnl!TdrResetFromTimeout
  dxgkrnl!TdrResetFromTimeoutWorkItem
```
**해석:** NVIDIA dGPU 엔진이 TDR 타임아웃(기본 ~2s) 내에 응답하지 못함 → dxgkrnl이 어댑터 리셋(`DXGADAPTER::Reset`)을 시도 → **리셋 자체가 `STATUS_INSUFFICIENT_RESOURCES`로 실패** → 복구 불가로 `TdrBugcheckOnTimeout`이 0x116 발생. 즉 **"GPU 행 + 복구(리셋) 실패"** 의 2단 실패.

핵심 소견:
- **결정적·반복적 시그니처**: 3건이 인자·스택 완전 동일 → 무작위 손상이 아닌 **체계적 실패 모드**. `!analyze`의 `MEMORY_CORRUPTION_LARGE`는 nvlddmkm 심볼 부재로 인한 **오탐 버킷**(실제 손상 아님).
- **드라이버 버전 교체에도 지속**: 3건이 서로 다른 DriverStore inf(`nvmii.inf_amd64_7251a3c0…`, `…_185e17ff…`, 현재 `…_52a4c0ca…`)에서 발생 → 최소 2~3개 드라이버 버전에 걸쳐 재발. **드라이버 업데이트로 해소되지 않음.**
- 발생이 Uptime 3h~22h 로 분산 → 단발 트랜션트가 아니라 **장시간 사용 중 누적/부하 조건**에서 재현.

## 3. 0x133 DPC_WATCHDOG_VIOLATION (심화)

```
Arg1=0 (단일 DPC가 할당시간 초과), Arg2=Arg3=0x500 ticks
DPC 체인:
  nt!KiRetireDpcList → nt!KiExecuteAllDpcs+0x692
  → nvlddmkm+0xeb819 → … → nvlddmkm+0x10dc07
  → nt!RtlCaptureStackBackTrace   (DISPATCH_LEVEL에서 스택 캡처 중 장기 체류)
PROCESS_NAME: msedgewebview2.exe (당시 현재 프로세스 — DPC와 무관)
```
**해석:** NVIDIA DPC가 DISPATCH_LEVEL에서 할당 시간을 초과(스택 백트레이스 캡처를 포함한 경로에서 장기 체류/스핀). 0x116(엔진 타임아웃)과 발생 양상은 다르나 **동일 드라이버(nvlddmkm)** 의 GPU 처리 지연이라는 공통 뿌리. 당시 webview2(브라우저 GPU 가속) 활성.

## 4. MEMORY.dmp / 덮어쓰기 타임라인 (확증)
이벤트 로그(WER 1001):
- 13:21 `0x000000ce`(nProtect) → MEMORY.DMP 저장
- 13:58 `0x00000133`(NVIDIA) → MEMORY.DMP **덮어씀**
→ 현재 `C:\Windows\MEMORY.dmp`(16GB)는 0x133(NVIDIA). **nProtect 0xCE 전체덤프가 이 NVIDIA 크래쉬로 유실된 것**이 로그로 확정됨. (EST_REM_11 참조)

## 5. 통합 가설 & 심화 한계 (정직)
- **확정(WHAT):** RTX 4060 Laptop dGPU의 **반복적 GPU 행 → TDR 리셋 실패(c000009a) → 0x116**, 그리고 1건의 **NVIDIA DPC 초과(0x133)**. 범인 모듈은 DPC/리셋 경로상 nvlddmkm로 단정.
- **미확정(WHY):** nvlddmkm 내부의 정확한 결함 지점은 **본 커널 미니덤프로 규명 불가** — NVIDIA 독점 드라이버(공개 심볼 없음, 108MB), 미니덤프에 GPU 엔진/펌웨어 상태 미포함. 리셋이 "리소스 부족"으로 실패하는 점은 드라이버 리커버리 경로의 자원 고갈/엔진 wedge 가능성을 시사하나 단정 불가.
- 기여 가능 요인(확인 불가, 후보): 드라이버 리셋 경로 버그, VRAM/커널 자원 압박, 하이브리드(Optimus)/MUX 전환, 노트북 열/전력, 브라우저·webview GPU 컴포지터 등 특정 GPU 소비자.

## 6. 권장 진단/다음 단계
1. **DDU 클린 제거 후 다른 브랜치 설치**(현재/최근 버전이 해소 못 했으므로 구 Studio 등 known-good로 롤백 테스트).
2. 부하 중 **GPU 온도/전력/VRAM 로깅**(HWiNFO/GPU-Z)으로 행 조건 포착.
3. **트리거 검증:** 브라우저/webview 하드웨어 가속 OFF 후 TDR 재발 여부(0x133이 webview2 동반).
4. 진단용으로 `TdrDelay` 상향 → 리셋 성공 여부 관찰(근본 수정 아님).
5. `nvidia-bug-report` 수집, MSI BIOS/vBIOS·GeForce 최신화, AC/배터리·스트레스(FurMark/3DMark) 재현, Intel iGPU 드라이버도 갱신(하이브리드 경로).

## 7. 분류
- 벤더 **NVIDIA**(+디바이스 OEM MSI). **신뢰성/안정성 이슈**(가용성), 보안 제보 성격 아님. 증거: 미니덤프 4 + 워치독 3 + 드라이버 버전/해시.
