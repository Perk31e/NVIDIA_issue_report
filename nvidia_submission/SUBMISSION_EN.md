# NVIDIA driver bug report (English draft)

Paste-ready text for the NVIDIA support ticket / GeForce driver feedback form. Fill in the `[link]` once the dump bundle is uploaded.

---

**Subject:** RTX 4060 Laptop: repeated 0x116 VIDEO_TDR_FAILURE (TDR reset fails with 0xC000009A) + 0x133 DPC_WATCHDOG in nvlddmkm, driver 617.42

**System**
- Laptop: MSI Creator Z17HX Studio A13VFT (board MS-17N2), BIOS E17N2IMS.10B (2024-04-25)
- GPU: NVIDIA GeForce RTX 4060 Laptop GPU, vBIOS 95.07.16.40.ec, 8 GB, PCI 01:00.0
- iGPU: Intel UHD Graphics, driver 31.0.101.4314 (hybrid / Optimus)
- NVIDIA driver: 617.42 (nvlddmkm.sys 32.0.16.1742, SHA256 DB407B964C11441642A1642A0922C35990DE974C267A08537C3432765365F84B)
- OS: Windows 11 Pro Build 26300
- TDR registry values (TdrLevel/TdrDelay/TdrDdiDelay): all default, never modified
- No overclocking or undervolting applied [확인 필요]

**Problem**
The system bugchecks during normal use (uptime between 3 and 22 hours):

| Date (local) | Bugcheck | Notes |
|---|---|---|
| 2026-09-13 13:38 | 0x116 VIDEO_TDR_FAILURE | Arg3 = 0xC000009A, Arg4 = 4 |
| 2026-09-14 23:49 | 0x116 | identical arguments and stack |
| 2026-10-02 14:21 | 0x116 | identical arguments and stack |
| 2026-10-16 13:40 | 0x133 DPC_WATCHDOG_VIOLATION | single DPC timeout inside nvlddmkm |

All three 0x116 dumps have the same signature: the GPU times out, dxgkrnl tries to reset the adapter, and the reset itself returns `STATUS_INSUFFICIENT_RESOURCES` (0xC000009A), so recovery fails:

```
dxgkrnl!TdrBugcheckOnTimeout+0x101
dxgkrnl!ADAPTER_RENDER::Reset+0x12d
dxgkrnl!DXGADAPTER::Reset+0x58a
dxgkrnl!TdrResetFromTimeout+0x15
dxgkrnl!TdrResetFromTimeoutWorkItem+0x22
```

The 0x133 is a single DPC exceeding its time budget (Arg2 = Arg3 = 0x500 ticks):

```
nt!KiExecuteAllDpcs+0x692
nvlddmkm+0xeb819 -> +0x12ce5c -> +0x12bfb3 -> +0x110f38 -> +0x10fd6f -> +0x10dc07
nt!RtlCaptureStackBackTrace+0x42
```

The 0x116 crashes happened under three different driver packages (DriverStore folders nvmii.inf_amd64_7251a3c0…, …_185e17ff…, …_52a4c0ca…), so updating the driver did not fix it.

The event log also shows two corrected PCIe AER errors (WHEA-Logger 17) on root port 8086:460D at 0:1:0, the dGPU's upstream port, on 2026-10-14.

**Attached** ([link])
- 4 kernel minidumps (3 x 0x116, 1 x 0x133)
- 3 LiveKernelReports\WATCHDOG captures, one per TDR
- DxDiag, nvidia-smi -q, filtered System event log (GPU/TDR/WHEA entries)
- A full MEMORY.DMP (16 GB) of the 0x133 crash is available on request

**Already in place / can do on request**
- A background logger records GPU temperature, power, clocks, VRAM, throttle reasons and foreground app every 5 s, so the state right before the next TDR will be captured.
- I can do a DDU clean install, test another driver branch, or run a debug driver if that helps.
