# dumps/

| 파일 | Bugcheck | 일시 | 요지 |
|---|---|---|---|
| `tdr_091326-17828-01_0x116.dmp` | 0x116 VIDEO_TDR_FAILURE | 2026-09-13 13:38 | GPU 타임아웃+리셋 실패(c000009a) |
| `tdr_091426-19140-01_0x116.dmp` | 0x116 | 2026-09-14 23:49 | 동일 시그니처 |
| `tdr_100226-21437-01_0x116.dmp` | 0x116 | 2026-10-02 14:21 | 동일 시그니처 |
| `dpcwatchdog_101626-20234-01_0x133.dmp` | 0x133 DPC_WATCHDOG | 2026-10-16 13:40 | nvlddmkm DPC 초과 |

cdb:
```
cdb -z <dump> -y srv*C:\symbols*https://msdl.microsoft.com/download/symbols -c "!analyze -v; q"
```

- 3건의 0x116은 인자(Arg3=c000009a)·dxgkrnl 리셋 스택이 **완전 동일** → 체계적 실패 모드.
- `../livekernelreports/WATCHDOG-*.dmp` = 같은 TDR 사건의 GPU 워치독 라이브 캡처.
- 전체덤프 `C:\Windows\MEMORY.dmp`(16GB)는 0x133과 동일 사건 — 대용량/독점심볼로 미포함.
- `MEMORY_CORRUPTION_LARGE` 버킷은 nvlddmkm 심볼 부재로 인한 오탐이며 실제 손상 아님.
