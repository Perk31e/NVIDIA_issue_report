# 분석 원자료 (cdb !analyze -v 발췌)

도구: WinDbg/cdb 10.0.22000.832, MS 공개 심볼. nvlddmkm 독점 심볼 없음(오프셋만).

## 0x116 ×3 — 공통 인자/스택
```
VIDEO_TDR_FAILURE (116)
Arg1 = TDR_RECOVERY_CONTEXT ptr   (091326: ffff97834959a010 / 091426: ffffe08038adc010 / 100226: ffffdc8ddbfed010)
Arg2 = 책임 모듈 owner tag → nvlddmkm
Arg3 = 0xC000009A  STATUS_INSUFFICIENT_RESOURCES   (3건 동일)
Arg4 = 0x4                                          (3건 동일)

STACK_TEXT (3건 동일):
  dxgkrnl!TdrBugcheckOnTimeout+0x101
  dxgkrnl!ADAPTER_RENDER::Reset+0x12d
  dxgkrnl!DXGADAPTER::Reset+0x58a
  dxgkrnl!TdrResetFromTimeout+0x15
  dxgkrnl!TdrResetFromTimeoutWorkItem+0x22
PROCESS_NAME: System
```
DriverStore inf(버전별로 상이):
- 091326: (구 버전)
- 091426: nvmii.inf_amd64_7251a3c076e80d80
- 100226: nvmii.inf_amd64_185e17ffef00b7bf
- 현재   : nvmii.inf_amd64_52a4c0ca7914a7b3  (nvlddmkm 32.0.16.1742)

## 0x133 — DPC watchdog
```
DPC_WATCHDOG_VIOLATION (133)  SINGLE_DPC_TIMEOUT_EXCEEDED
Arg1=0  Arg2=0x500  Arg3=0x500 ticks  Arg4=nt!DPC_WATCHDOG_GLOBAL_TRIAGE_BLOCK

DPC 체인:
  nt!KiRetireDpcList → nt!KiExecuteAllDpcs+0x692
  nvlddmkm+0xeb819
  nvlddmkm+0x12ce5c
  nvlddmkm+0x12bfb3
  nvlddmkm+0x110f38
  nvlddmkm+0x10fd6f
  nvlddmkm+0x10dc07  → nt!RtlCaptureStackBackTrace+0x42
PROCESS_NAME: msedgewebview2.exe
```

## 환경
- GPU: NVIDIA GeForce RTX 4060 Laptop (DriverVersion 32.0.16.1742, Date 2026-09-30/10-02) + Intel UHD(31.0.101.4314)
- TDR 레지스트리 TdrLevel/TdrDelay/TdrDdiDelay: 전부 기본값(미설정)
- 이벤트 로그: WER 1001 — 13:58 0x133→MEMORY.DMP. 같은 날 다른(무관) bugcheck가 잇따라 MEMORY.DMP를 순차 덮어써 0x133만 전체덤프 잔존. Kernel-Power 41(비정상 종료) 동반.
- LiveKernelReports\WATCHDOG: 20260913-1338 / 20260914-2349 / 20261002-1421 (TDR 사건과 1:1 대응)
