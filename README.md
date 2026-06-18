<div align="center">

```
 ██╗   ██╗ ██████╗ ████████╗    ███████╗██╗     ███████╗███████╗██████╗
 ██║   ██║██╔════╝ ╚══██╔══╝    ██╔════╝██║     ██╔════╝██╔════╝██╔══██╗
 ██║   ██║██║  ███╗   ██║       ███████╗██║     █████╗  █████╗  ██████╔╝
 ╚██╗ ██╔╝██║   ██║   ██║       ╚════██║██║     ██╔══╝  ██╔══╝  ██╔═══╝
  ╚████╔╝ ╚██████╔╝   ██║       ███████║███████╗███████╗███████╗██║
   ╚═══╝   ╚═════╝    ╚═╝       ╚══════╝╚══════╝╚══════╝╚══════╝╚═╝
```

# VGT Power Sleep Timer
### Hardened Windows Sleep Scheduler · Dark UI · Tray-Hide · Borderless

[![Platform](https://img.shields.io/badge/Platform-Windows-0078D4?style=for-the-badge&logo=windows)](#)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-5391FE?style=for-the-badge&logo=powershell)](https://learn.microsoft.com/en-us/powershell/)
[![Status](https://img.shields.io/badge/Status-PLATIN-silver?style=for-the-badge)](#)
[![VGT](https://img.shields.io/badge/VGT-VisionGaiaTechnology-red?style=for-the-badge)](https://visiongaiatechnology.de)
[![License](https://img.shields.io/badge/License-Proprietary-red?style=for-the-badge)](#)

**HARD SLEEP · ZERO RUNTIME DEPENDENCIES · TRAY-RESIDENT**

</div>

---

## 🔍 What is VGT Power Sleep Timer?

Windows has no native GUI tool for scheduling a sleep event with live duration control. Task Scheduler is overkill, third-party apps phone home, and `shutdown /h` gives you no feedback and no way to cancel.

**VGT Power Sleep Timer closes this gap.**

A self-contained PowerShell GUI that schedules a hard Windows sleep (`SetSuspendState`) with a live countdown, runtime duration editing, tray-hide capability and clean cancel at any point — zero external dependencies, zero install, one script.

```
Standard Windows Sleep Scheduling:
  Task Scheduler       → complex, no live feedback, no cancel UI
  shutdown /h          → fires immediately, no countdown
  Third-party apps     → installer required, network calls, bloat

VGT Power Sleep Timer:
  Script launched      → dark borderless UI appears
  Countdown live       → HH:MM:SS with progress bar
  Duration editable    → at any point while running
  Minimize to tray     → UI hidden, timer keeps running
  Cancel anytime       → clean abort, no sleep triggered
  Timer reaches zero   → SetSuspendState fires, hard sleep
```

---

## ⚡ Features

- **Hard Sleep via `PowrProf.dll`** — calls `SetSuspendState` directly, same API Windows itself uses
- **Live countdown** — large `HH:MM:SS` display with animated progress bar
- **Runtime duration editing** — change hours/minutes while the timer is running; takes effect immediately
- **±15 min quick buttons** — fast adjustment without touching the inputs
- **Tray-hide** — minimize to system tray, timer continues in background
- **Balloon notification** — one-time tip on first hide explaining tray double-click restore
- **Movable borderless window** — drag anywhere by the header
- **Dark glassmorphic UI** — `#0A0D12` base, `#00FFCC` accent, Consolas countdown font
- **Re-run safe** — `Add-Type` guards via `Get-LoadedType` prevent class redeclaration errors on re-run in the same session
- **DoubleBuffered form** — flicker-free rendering via C# `SleepTimerForm` subclass
- **DWM rounded corners + dark title bar** — modern Windows 11 chrome via `DwmSetWindowAttribute`
- **No install, no dependencies** — pure PowerShell 5.1 + .NET Framework (included in Windows)

---

## 🖥️ UI Layout



<img width="537" height="377" alt="image" src="https://github.com/user-attachments/assets/00eb48ae-6fd0-470f-9c0e-55fd81bb14e8" />


---

## 🚀 Usage

### Basic Launch

```powershell
# Default: 3 hours
.\VGT-SleepTimer.ps1

# Custom duration
.\VGT-SleepTimer.ps1 -DurationHours 1.5
.\VGT-SleepTimer.ps1 -DurationHours 0.5    # 30 minutes
.\VGT-SleepTimer.ps1 -DurationHours 8      # 8 hours
```

### Execution Policy

If PowerShell blocks the script, run once with:

```powershell
powershell.exe -ExecutionPolicy Bypass -File ".\VGT-SleepTimer.ps1" -DurationHours 2
```

Or set permanently for your user:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Parameters

| Parameter | Type | Default | Range | Description |
|---|---|---|---|---|
| `-DurationHours` | `double` | `3` | `0.016 – 168` | Initial countdown duration in hours |

Minimum enforced: **60 seconds**. Maximum enforced: **168 hours (7 days)**.

---

## 🎛️ Controls

| Control | Action |
|---|---|
| **SETZEN** | Apply the hours/minutes inputs as new remaining time |
| **+15 MIN** | Add 15 minutes to remaining time |
| **-15 MIN** | Subtract 15 minutes (minimum 60 seconds) |
| **HIDDEN** | Hide UI to system tray — timer keeps running |
| **ABBRECHEN** | Cancel timer and close — no sleep triggered |
| **— (header)** | Hide to tray |
| **✕ (header)** | Cancel and close |
| **Tray double-click** | Toggle UI visibility |
| **Tray menu → UI verbergen** | Hide to tray |
| **Tray menu → UI anzeigen** | Show UI |
| **Tray menu → Timer abbrechen** | Cancel and close |

---

## 🏛️ Architecture

```
Script Entry
  ↓
Execution Guards
  → Set-StrictMode -Version Latest
  → $ErrorActionPreference = 'Stop'
  ↓
Type Loading (Re-run Safe)
  → Get-LoadedType checks AppDomain before Add-Type
  → VGT.SleepTimer.PowerManager   ← SetSuspendState P/Invoke
  → VGT.SleepTimer.WindowNative   ← ReleaseCapture / SendMessage / DwmSetWindowAttribute
  → VGT.SleepTimer.SleepTimerForm ← C# Form subclass with DoubleBuffered + OptimizedDoubleBuffer
  ↓
UI Construction
  → Borderless form (FormBorderStyle::None)
  → Header panel (draggable via WM_NCLBUTTONDOWN)
  → Custom-painted progress bar panel
  → NumericUpDown inputs (hours / minutes)
  → System.Windows.Forms.Timer (1000ms tick)
  ↓
Tray Icon
  → NotifyIcon + ContextMenu
  → Toggle-TimerWindow on DoubleClick
  → Balloon tip on first hide
  ↓
Timer Tick Loop
  → remainingSeconds--
  → Update-Display → countdownLabel + progressPanel.Invalidate()
  → Update-TrayText (max 63 chars)
  → remainingSeconds <= 0 → Invoke-SystemSleep
  ↓
Sleep Trigger
  → timer.Stop()
  → 2-second UI flash ("SLEEP WIRD AUSGELÖST...")
  → SetSuspendState(hibernate: false, forceCritical: true, disableWakeEvent: false)
  → Win32 error code surfaced on failure
  → NotifyIcon disposed → form.Close()
```

---

## 🔒 Technical Details

### Sleep API

```powershell
[VGT.SleepTimer.PowerManager]::SetSuspendState(
    $false,   # hibernate = false → sleep (S3/Modern Standby)
    $true,    # forceCritical = true → force immediate
    $false    # disableWakeEvent = false → allow scheduled wake
)
```

`SetSuspendState` is called from `PowrProf.dll` via P/Invoke. On failure, the Win32 error code is retrieved via `Marshal.GetLastWin32Error()` and shown in a message box.

### Time Math

All duration calculations use integer seconds internally. `Math.Floor` is applied at every conversion step — no floating-point rounding drift in the countdown.

```powershell
$hours   = [int][Math]::Floor($seconds / 3600)
$minutes = [int][Math]::Floor(($seconds % 3600) / 60)
$display = '{0:00}:{1:00}:{2:00}' -f $hours, $minutes, $seconds % 60
```

### Re-Run Safety

Loading `Add-Type` twice in the same PowerShell session throws a type-already-declared error. VGTAstra guards against this:

```powershell
function Get-LoadedType {
    param([string]$FullName)
    foreach ($assembly in [AppDomain]::CurrentDomain.GetAssemblies()) {
        $type = $assembly.GetType($FullName, $false, $false)
        if ($null -ne $type) { return $type }
    }
    return $null
}

if ($null -eq (Get-LoadedType 'VGT.SleepTimer.PowerManager')) {
    Add-Type -TypeDefinition @"..."@
}
```

### DoubleBuffered Rendering

PowerShell cannot set `DoubleBuffered = $true` on `System.Windows.Forms.Form` directly — it is a protected property. VGTAstra works around this with a minimal C# subclass:

```csharp
public sealed class SleepTimerForm : Form {
    public SleepTimerForm() {
        this.SetStyle(
            ControlStyles.AllPaintingInWmPaint |
            ControlStyles.UserPaint |
            ControlStyles.OptimizedDoubleBuffer |
            ControlStyles.ResizeRedraw,
            true
        );
        this.UpdateStyles();
    }
}
```

### DWM Chrome

On Windows 11, the DWM is queried for rounded corners and dark title bar:

```powershell
# Rounded corners (attr 33 = DWMWA_WINDOW_CORNER_PREFERENCE, value 2 = DWMWCP_ROUND)
[VGT.SleepTimer.WindowNative]::DwmSetWindowAttribute($form.Handle, 33, [ref]2, 4)

# Dark title bar (attr 20 = DWMWA_USE_IMMERSIVE_DARK_MODE, value 1 = enabled)
[VGT.SleepTimer.WindowNative]::DwmSetWindowAttribute($form.Handle, 20, [ref]1, 4)
```

Both calls are wrapped in `try/catch` — they fail silently on Windows 10 without breaking the app.

---

## ⚙️ Requirements

| Requirement | Value |
|---|---|
| **OS** | Windows 10 / 11 |
| **PowerShell** | 5.1+ (included in Windows) |
| **.NET Framework** | 4.x (included in Windows) |
| **Sleep capability** | Sleep (S3) or Modern Standby must be enabled |
| **Permissions** | Standard user — no admin required |
| **External dependencies** | None |

---

## ⚠️ Notes

**Sleep must be enabled on your system.** If your device uses Hibernate-only or if sleep is disabled via Group Policy, `SetSuspendState` will return `false` and show the Win32 error code.

**Hybrid Sleep / Fast Startup** may intercept the sleep call on some systems. If sleep doesn't trigger, check Power Options → Sleep settings.

**The script does not survive sleep.** Once the PC wakes, the timer is gone — this is intentional. Use Task Scheduler if you need a post-wake action.

**Tray icon requires a system tray.** If the system tray is hidden or the notification area is suppressed, the hide functionality still works but the icon may not be visible.

---

## 🔗 VGT Ecosystem

| Tool | Type | Purpose |
|---|---|---|
| ⏱️ **VGT Power Sleep Timer** | **Desktop Utility** | Scheduled Windows sleep with live UI — you are here |
| 🖥️ **[VGT WP-Desk](https://github.com/visiongaiatechnology/vgtdesk)** | **OS-Layer / UX** | Hardened WordPress operator workspace |
| ⚡ **[VGT Auto-Punisher](https://github.com/visiongaiatechnology/vgt-auto-punisher)** | **IDS** | L4+L7 Hybrid IDS for Linux |
| 🛡️ **[VGT Myrmidon](https://github.com/visiongaiatechnology/vgtmyrmidon)** | **ZTNA** | Zero Trust device registry |
| ⚔️ **[VGT Sentinel](https://github.com/visiongaiatechnology/sentinelcom)** | **WAF / IDS** | Zero-Trust WordPress WAF |

---

## 💰 Support the Project

[![Donate via PayPal](https://img.shields.io/badge/Donate-PayPal-00457C?style=for-the-badge&logo=paypal)](https://www.paypal.com/paypalme/dergoldenelotus)

| Method | Address |
|---|---|
| **PayPal** | [paypal.me/dergoldenelotus](https://www.paypal.com/paypalme/dergoldenelotus) |
| **Bitcoin** | `bc1q3ue5gq822tddmkdrek79adlkm36fatat3lz0dm` |
| **ETH / USDT (ERC-20)** | `0xD37DEfb09e07bD775EaaE9ccDaFE3a5b2348Fe85` |

---

## 📄 License

Proprietary · © 2026 VisionGaia Technology · Cologne, Germany

---

<div align="center">

**VISIONGAIATECHNOLOGY – WE ARCHITECT THE FUTURE OF SECURITY.**

[![VGT](https://img.shields.io/badge/VisionGaia-Technology-gold?style=for-the-badge)](https://visiongaiatechnology.de)

*VGT Power Sleep Timer — PowrProf.dll SetSuspendState // Re-Run Safe Add-Type Guards // DoubleBuffered C# Form Subclass // DWM Rounded Corners // Dark Glassmorphic UI // Tray-Hide // Live Duration Editing // Zero Dependencies // PLATIN*

</div>
