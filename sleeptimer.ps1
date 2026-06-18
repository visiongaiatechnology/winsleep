# // STATUS: PLATIN
#requires -version 5.1
<#
.SYNOPSIS
# ==============================================================================
# VISIONGAIATECHNOLOGY: VGT Power Sleep Timer
# STATUS: Stable
# ARCHITEKTUR: PowerShell
# ZWECK: Schlafenstimer - Sleeptimer
# ==============================================================================
# 
# Copyright (c) 2026 VISIONGAIATECHNOLOGY
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# ==============================================================================
#>


param(
    [double]$DurationHours = 3
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$MinSeconds = 60
$MaxHours   = 168
$MaxSeconds = $MaxHours * 3600

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Get-LoadedType {
    param([Parameter(Mandatory)][string]$FullName)

    foreach ($assembly in [AppDomain]::CurrentDomain.GetAssemblies()) {
        $type = $assembly.GetType($FullName, $false, $false)
        if ($null -ne $type) {
            return $type
        }
    }

    return $null
}

$powerManagerTypeName = 'VGT.SleepTimer.PowerManager'
if ($null -eq (Get-LoadedType -FullName $powerManagerTypeName)) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace VGT.SleepTimer {
    public static class PowerManager {
        [DllImport("PowrProf.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetSuspendState(bool hibernate, bool forceCritical, bool disableWakeEvent);
    }
}
"@
}

$windowNativeTypeName = 'VGT.SleepTimer.WindowNative'
if ($null -eq (Get-LoadedType -FullName $windowNativeTypeName)) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace VGT.SleepTimer {
    public static class WindowNative {
        public const int WM_NCLBUTTONDOWN = 0xA1;
        public const int HT_CAPTION = 0x2;

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool ReleaseCapture();

        [DllImport("user32.dll")]
        public static extern int SendMessage(IntPtr hWnd, int msg, int wParam, int lParam);

        [DllImport("dwmapi.dll")]
        public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
    }
}
"@
}

$sleepTimerFormTypeName = 'VGT.SleepTimer.SleepTimerForm'
if ($null -eq (Get-LoadedType -FullName $sleepTimerFormTypeName)) {
    Add-Type -ReferencedAssemblies @('System.Windows.Forms', 'System.Drawing') -TypeDefinition @"
using System.Windows.Forms;

namespace VGT.SleepTimer {
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
}
"@
}

function New-Color {
    param([Parameter(Mandatory)][string]$Hex)

    return [System.Drawing.ColorTranslator]::FromHtml($Hex)
}

function Convert-ToFloorInt {
    param([Parameter(Mandatory)][decimal]$Value)

    return [int][Math]::Floor([double]$Value)
}

function Normalize-DurationSeconds {
    param([Parameter(Mandatory)][double]$Seconds)

    $floored = [int][Math]::Floor($Seconds)

    if ($floored -lt $MinSeconds) {
        return $MinSeconds
    }

    if ($floored -gt $MaxSeconds) {
        return $MaxSeconds
    }

    return $floored
}

function Format-Remaining {
    param([Parameter(Mandatory)][int]$Seconds)

    $safeSeconds = [Math]::Max(0, $Seconds)
    $time = [TimeSpan]::FromSeconds($safeSeconds)

    if ($time.TotalDays -ge 1) {
        $days = [int][Math]::Floor($time.TotalDays)
        return '{0}d {1:00}:{2:00}:{3:00}' -f $days, $time.Hours, $time.Minutes, $time.Seconds
    }

    $wholeHours = [int][Math]::Floor($time.TotalHours)
    return '{0:00}:{1:00}:{2:00}' -f $wholeHours, $time.Minutes, $time.Seconds
}

function Set-ButtonVisual {
    param(
        [Parameter(Mandatory)][System.Windows.Forms.Button]$Button,
        [Parameter(Mandatory)][string]$BaseHex,
        [Parameter(Mandatory)][string]$HoverHex,
        [Parameter(Mandatory)][string]$ForeHex
    )

    $baseColor = New-Color $BaseHex
    $hoverColor = New-Color $HoverHex
    $foreColor = New-Color $ForeHex

    $Button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $Button.FlatAppearance.BorderSize = 0
    $Button.BackColor = $baseColor
    $Button.ForeColor = $foreColor
    $Button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $Button.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)

    $Button.Add_MouseEnter({
        param($sender, $eventArgs)
        $sender.BackColor = $hoverColor
    }.GetNewClosure())

    $Button.Add_MouseLeave({
        param($sender, $eventArgs)
        $sender.BackColor = $baseColor
    }.GetNewClosure())
}

try {
    [System.Windows.Forms.Application]::EnableVisualStyles()
} catch {}

try {
    if ([System.Windows.Forms.Application]::OpenForms.Count -eq 0) {
        [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
    }
} catch [System.InvalidOperationException] {
} catch {}

$initialSeconds = Normalize-DurationSeconds -Seconds ([Math]::Max([double]$DurationHours, ($MinSeconds / 3600.0)) * 3600.0)

$script:totalSeconds = $initialSeconds
$script:remainingSeconds = $initialSeconds
$script:hidden = $false
$script:isTerminating = $false
$script:balloonShown = $false

$form = New-Object VGT.SleepTimer.SleepTimerForm
$form.Text = 'VGT Power Sleep Timer'
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.BackColor = New-Color '#0A0D12'
$form.Size = New-Object System.Drawing.Size(540, 380)
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.TopMost = $true
$form.ShowInTaskbar = $false
$form.Opacity = 0.98

$form.Add_Paint({
    param($sender, $eventArgs)

    $graphics = $eventArgs.Graphics
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

    $borderPen = New-Object System.Drawing.Pen((New-Color '#2B3342'), 1)
    $accentPen = New-Object System.Drawing.Pen((New-Color '#00FFCC'), 1)

    try {
        $graphics.DrawRectangle($borderPen, 0, 0, $sender.Width - 1, $sender.Height - 1)
        $graphics.DrawLine($accentPen, 1, 48, $sender.Width - 2, 48)
    } finally {
        $borderPen.Dispose()
        $accentPen.Dispose()
    }
})

$header = New-Object System.Windows.Forms.Panel
$header.BackColor = New-Color '#111722'
$header.Location = New-Object System.Drawing.Point(0, 0)
$header.Size = New-Object System.Drawing.Size(540, 48)
$form.Controls.Add($header)

$accentDiamond = New-Object System.Windows.Forms.Label
$accentDiamond.Text = '◆'
$accentDiamond.Font = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
$accentDiamond.ForeColor = New-Color '#00FFCC'
$accentDiamond.BackColor = [System.Drawing.Color]::Transparent
$accentDiamond.AutoSize = $false
$accentDiamond.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$accentDiamond.Location = New-Object System.Drawing.Point(12, 0)
$accentDiamond.Size = New-Object System.Drawing.Size(34, 48)
$header.Controls.Add($accentDiamond)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = 'VGT POWER SLEEP TIMER'
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = New-Color '#F8FAFC'
$titleLabel.BackColor = [System.Drawing.Color]::Transparent
$titleLabel.AutoSize = $false
$titleLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$titleLabel.Location = New-Object System.Drawing.Point(48, 0)
$titleLabel.Size = New-Object System.Drawing.Size(300, 48)
$header.Controls.Add($titleLabel)

$modeLabel = New-Object System.Windows.Forms.Label
$modeLabel.Text = 'HARD SLEEP'
$modeLabel.Font = New-Object System.Drawing.Font("Consolas", 8, [System.Drawing.FontStyle]::Bold)
$modeLabel.ForeColor = New-Color '#00FFCC'
$modeLabel.BackColor = New-Color '#0B111A'
$modeLabel.AutoSize = $false
$modeLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$modeLabel.Location = New-Object System.Drawing.Point(356, 13)
$modeLabel.Size = New-Object System.Drawing.Size(86, 22)
$header.Controls.Add($modeLabel)

$btnHide = New-Object System.Windows.Forms.Label
$btnHide.Text = '—'
$btnHide.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 12, [System.Drawing.FontStyle]::Bold)
$btnHide.ForeColor = New-Color '#7C8798'
$btnHide.BackColor = [System.Drawing.Color]::Transparent
$btnHide.AutoSize = $false
$btnHide.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$btnHide.Location = New-Object System.Drawing.Point(444, 0)
$btnHide.Size = New-Object System.Drawing.Size(48, 48)
$btnHide.Cursor = [System.Windows.Forms.Cursors]::Hand
$header.Controls.Add($btnHide)

$btnClose = New-Object System.Windows.Forms.Label
$btnClose.Text = '✕'
$btnClose.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 12, [System.Drawing.FontStyle]::Bold)
$btnClose.ForeColor = New-Color '#7C8798'
$btnClose.BackColor = [System.Drawing.Color]::Transparent
$btnClose.AutoSize = $false
$btnClose.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$btnClose.Location = New-Object System.Drawing.Point(492, 0)
$btnClose.Size = New-Object System.Drawing.Size(48, 48)
$btnClose.Cursor = [System.Windows.Forms.Cursors]::Hand
$header.Controls.Add($btnClose)

$mainPanel = New-Object System.Windows.Forms.Panel
$mainPanel.BackColor = New-Color '#0A0D12'
$mainPanel.Location = New-Object System.Drawing.Point(0, 48)
$mainPanel.Size = New-Object System.Drawing.Size(540, 332)
$form.Controls.Add($mainPanel)

$statusNeutralColor = New-Color '#64748B'
$statusAccentColor = New-Color '#00FFCC'
$statusNeutralArgb = $statusNeutralColor.ToArgb()

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = 'ACTIVE TIMER · RESTZEIT LIVE ÄNDERBAR'
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
$statusLabel.ForeColor = $statusNeutralColor
$statusLabel.BackColor = [System.Drawing.Color]::Transparent
$statusLabel.AutoSize = $false
$statusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$statusLabel.Location = New-Object System.Drawing.Point(32, 26)
$statusLabel.Size = New-Object System.Drawing.Size(476, 24)
$mainPanel.Controls.Add($statusLabel)

$countdownLabel = New-Object System.Windows.Forms.Label
$countdownLabel.Text = Format-Remaining -Seconds $script:remainingSeconds
$countdownLabel.Font = New-Object System.Drawing.Font("Consolas", 38, [System.Drawing.FontStyle]::Bold)
$countdownLabel.ForeColor = New-Color '#E5E7EB'
$countdownLabel.BackColor = [System.Drawing.Color]::Transparent
$countdownLabel.AutoSize = $false
$countdownLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$countdownLabel.Location = New-Object System.Drawing.Point(32, 56)
$countdownLabel.Size = New-Object System.Drawing.Size(476, 72)
$mainPanel.Controls.Add($countdownLabel)

$progressPanel = New-Object System.Windows.Forms.Panel
$progressPanel.BackColor = New-Color '#111827'
$progressPanel.Location = New-Object System.Drawing.Point(52, 142)
$progressPanel.Size = New-Object System.Drawing.Size(436, 12)
$mainPanel.Controls.Add($progressPanel)

$progressPanel.Add_Paint({
    param($sender, $eventArgs)

    $graphics = $eventArgs.Graphics
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

    $backgroundBrush = New-Object System.Drawing.SolidBrush((New-Color '#111827'))
    $fillBrush = New-Object System.Drawing.SolidBrush((New-Color '#00FFCC'))
    $edgePen = New-Object System.Drawing.Pen((New-Color '#273244'), 1)

    try {
        $graphics.FillRectangle($backgroundBrush, 0, 0, $sender.Width, $sender.Height)

        $elapsed = [Math]::Max(0, $script:totalSeconds - $script:remainingSeconds)
        $ratio = 0.0

        if ($script:totalSeconds -gt 0) {
            $ratio = [Math]::Min(1.0, [Math]::Max(0.0, [double]$elapsed / [double]$script:totalSeconds))
        }

        $fillWidth = [int][Math]::Floor(($sender.Width - 2) * $ratio)

        if ($fillWidth -gt 0) {
            $graphics.FillRectangle($fillBrush, 1, 1, $fillWidth, $sender.Height - 2)
        }

        $graphics.DrawRectangle($edgePen, 0, 0, $sender.Width - 1, $sender.Height - 1)
    } finally {
        $backgroundBrush.Dispose()
        $fillBrush.Dispose()
        $edgePen.Dispose()
    }
})

$inputTitleLabel = New-Object System.Windows.Forms.Label
$inputTitleLabel.Text = 'NEUE RESTZEIT SETZEN'
$inputTitleLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
$inputTitleLabel.ForeColor = New-Color '#CBD5E1'
$inputTitleLabel.BackColor = [System.Drawing.Color]::Transparent
$inputTitleLabel.AutoSize = $false
$inputTitleLabel.Location = New-Object System.Drawing.Point(52, 178)
$inputTitleLabel.Size = New-Object System.Drawing.Size(436, 20)
$mainPanel.Controls.Add($inputTitleLabel)

$hoursInput = New-Object System.Windows.Forms.NumericUpDown
$hoursInput.Minimum = 0
$hoursInput.Maximum = $MaxHours
$hoursInput.DecimalPlaces = 0
$hoursInput.Increment = 1
$hoursInput.ThousandsSeparator = $false
$hoursInput.Value = [decimal][Math]::Floor($script:totalSeconds / 3600)
$hoursInput.BackColor = New-Color '#111827'
$hoursInput.ForeColor = New-Color '#E5E7EB'
$hoursInput.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$hoursInput.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Right
$hoursInput.Location = New-Object System.Drawing.Point(52, 208)
$hoursInput.Size = New-Object System.Drawing.Size(76, 24)
$mainPanel.Controls.Add($hoursInput)

$hoursUnitLabel = New-Object System.Windows.Forms.Label
$hoursUnitLabel.Text = 'STD'
$hoursUnitLabel.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
$hoursUnitLabel.ForeColor = New-Color '#64748B'
$hoursUnitLabel.BackColor = [System.Drawing.Color]::Transparent
$hoursUnitLabel.AutoSize = $false
$hoursUnitLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$hoursUnitLabel.Location = New-Object System.Drawing.Point(134, 206)
$hoursUnitLabel.Size = New-Object System.Drawing.Size(48, 26)
$mainPanel.Controls.Add($hoursUnitLabel)

$minutesInput = New-Object System.Windows.Forms.NumericUpDown
$minutesInput.Minimum = 0
$minutesInput.Maximum = 59
$minutesInput.DecimalPlaces = 0
$minutesInput.Increment = 1
$minutesInput.ThousandsSeparator = $false
$minutesInput.Value = [decimal][Math]::Floor(($script:totalSeconds % 3600) / 60)
$minutesInput.BackColor = New-Color '#111827'
$minutesInput.ForeColor = New-Color '#E5E7EB'
$minutesInput.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$minutesInput.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Right
$minutesInput.Location = New-Object System.Drawing.Point(188, 208)
$minutesInput.Size = New-Object System.Drawing.Size(76, 24)
$mainPanel.Controls.Add($minutesInput)

$minutesUnitLabel = New-Object System.Windows.Forms.Label
$minutesUnitLabel.Text = 'MIN'
$minutesUnitLabel.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
$minutesUnitLabel.ForeColor = New-Color '#64748B'
$minutesUnitLabel.BackColor = [System.Drawing.Color]::Transparent
$minutesUnitLabel.AutoSize = $false
$minutesUnitLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$minutesUnitLabel.Location = New-Object System.Drawing.Point(270, 206)
$minutesUnitLabel.Size = New-Object System.Drawing.Size(48, 26)
$mainPanel.Controls.Add($minutesUnitLabel)

$setButton = New-Object System.Windows.Forms.Button
$setButton.Text = 'SETZEN'
$setButton.Location = New-Object System.Drawing.Point(336, 204)
$setButton.Size = New-Object System.Drawing.Size(152, 32)
Set-ButtonVisual -Button $setButton -BaseHex '#008F78' -HoverHex '#00B894' -ForeHex '#FFFFFF'
$mainPanel.Controls.Add($setButton)

$minusButton = New-Object System.Windows.Forms.Button
$minusButton.Text = '-15 MIN'
$minusButton.Location = New-Object System.Drawing.Point(52, 264)
$minusButton.Size = New-Object System.Drawing.Size(104, 34)
Set-ButtonVisual -Button $minusButton -BaseHex '#1E293B' -HoverHex '#334155' -ForeHex '#E5E7EB'
$mainPanel.Controls.Add($minusButton)

$plusButton = New-Object System.Windows.Forms.Button
$plusButton.Text = '+15 MIN'
$plusButton.Location = New-Object System.Drawing.Point(166, 264)
$plusButton.Size = New-Object System.Drawing.Size(104, 34)
Set-ButtonVisual -Button $plusButton -BaseHex '#1E293B' -HoverHex '#334155' -ForeHex '#E5E7EB'
$mainPanel.Controls.Add($plusButton)

$hideButton = New-Object System.Windows.Forms.Button
$hideButton.Text = 'HIDDEN'
$hideButton.Location = New-Object System.Drawing.Point(280, 264)
$hideButton.Size = New-Object System.Drawing.Size(96, 34)
Set-ButtonVisual -Button $hideButton -BaseHex '#172033' -HoverHex '#24314A' -ForeHex '#E5E7EB'
$mainPanel.Controls.Add($hideButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = 'ABBRECHEN'
$cancelButton.Location = New-Object System.Drawing.Point(386, 264)
$cancelButton.Size = New-Object System.Drawing.Size(102, 34)
Set-ButtonVisual -Button $cancelButton -BaseHex '#7F1D1D' -HoverHex '#B91C1C' -ForeHex '#FEE2E2'
$mainPanel.Controls.Add($cancelButton)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000

$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
$notifyIcon.Text = 'Sleep-Timer läuft'
$notifyIcon.Visible = $true

$trayMenu = New-Object System.Windows.Forms.ContextMenu

$menuShowHide = New-Object System.Windows.Forms.MenuItem
$menuShowHide.Text = 'UI verbergen'

$menuSetVisible = New-Object System.Windows.Forms.MenuItem
$menuSetVisible.Text = 'UI anzeigen'

$menuCancel = New-Object System.Windows.Forms.MenuItem
$menuCancel.Text = 'Timer abbrechen'

$trayMenu.MenuItems.Add($menuShowHide) | Out-Null
$trayMenu.MenuItems.Add($menuSetVisible) | Out-Null
$trayMenu.MenuItems.Add('-') | Out-Null
$trayMenu.MenuItems.Add($menuCancel) | Out-Null

$notifyIcon.ContextMenu = $trayMenu

function Update-TrayText {
    $remaining = Format-Remaining -Seconds $script:remainingSeconds
    $text = "Sleep in $remaining"

    if ($text.Length -gt 63) {
        $text = $text.Substring(0, 63)
    }

    try {
        $notifyIcon.Text = $text
    } catch {}
}

function Update-Display {
    $countdownLabel.Text = Format-Remaining -Seconds $script:remainingSeconds
    $progressPanel.Invalidate()
    Update-TrayText
}

function Sync-InputsFromSeconds {
    param([Parameter(Mandatory)][int]$Seconds)

    $safeSeconds = Normalize-DurationSeconds -Seconds $Seconds

    $hoursInput.Value = [decimal][Math]::Floor($safeSeconds / 3600)
    $minutesInput.Value = [decimal][Math]::Floor(($safeSeconds % 3600) / 60)
}

function Set-TimerDuration {
    param([Parameter(Mandatory)][int]$Seconds)

    $safeSeconds = Normalize-DurationSeconds -Seconds $Seconds

    $script:totalSeconds = $safeSeconds
    $script:remainingSeconds = $safeSeconds

    Sync-InputsFromSeconds -Seconds $safeSeconds
    Update-Display
}

function Get-RequestedSeconds {
    $hours = Convert-ToFloorInt -Value $hoursInput.Value
    $minutes = Convert-ToFloorInt -Value $minutesInput.Value

    $seconds = ($hours * 3600) + ($minutes * 60)

    if ($seconds -lt $MinSeconds -or $seconds -gt $MaxSeconds) {
        [System.Windows.Forms.MessageBox]::Show(
            "Bitte eine Restzeit zwischen 1 Minute und $MaxHours Stunden wählen.",
            "Ungültige Zeit",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null

        return $null
    }

    return [int]$seconds
}

function Show-TimerWindow {
    if ($script:isTerminating) {
        return
    }

    $form.Show()
    $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
    $form.TopMost = $true
    $form.Activate()

    $script:hidden = $false
    $menuShowHide.Text = 'UI verbergen'
}

function Hide-TimerWindow {
    if ($script:isTerminating) {
        return
    }

    $form.Hide()

    $script:hidden = $true
    $menuShowHide.Text = 'UI anzeigen'

    if (-not $script:balloonShown) {
        $script:balloonShown = $true

        try {
            $notifyIcon.ShowBalloonTip(
                2500,
                "Sleep-Timer läuft weiter",
                "Doppelklick auf das Tray-Icon zeigt das UI wieder.",
                [System.Windows.Forms.ToolTipIcon]::Info
            )
        } catch {}
    }
}

function Toggle-TimerWindow {
    if ($script:hidden) {
        Show-TimerWindow
    } else {
        Hide-TimerWindow
    }
}

function Stop-TimerAndClose {
    param(
        [bool]$ShowMessage = $false
    )

    if ($script:isTerminating) {
        return
    }

    $script:isTerminating = $true

    try {
        $timer.Stop()
    } catch {}

    if ($ShowMessage) {
        [System.Windows.Forms.MessageBox]::Show(
            "Sleep-Timer wurde abgebrochen.",
            "Abgebrochen",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }

    try {
        $notifyIcon.Visible = $false
        $notifyIcon.Dispose()
    } catch {}

    try {
        $form.Close()
    } catch {}
}

function Invoke-SystemSleep {
    if ($script:isTerminating) {
        return
    }

    $script:isTerminating = $true

    try {
        $timer.Stop()
    } catch {}

    $script:remainingSeconds = 0
    Update-Display

    $statusLabel.Text = 'SLEEP WIRD AUSGELÖST...'
    $statusLabel.ForeColor = $statusAccentColor
    $form.Refresh()

    Start-Sleep -Seconds 2

    $sleepTriggered = [VGT.SleepTimer.PowerManager]::SetSuspendState($false, $true, $false)

    if (-not $sleepTriggered) {
        $lastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()

        [System.Windows.Forms.MessageBox]::Show(
            "Sleep-Aufruf fehlgeschlagen. Windows-Fehlercode: $lastError",
            "Sleep fehlgeschlagen",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }

    try {
        $notifyIcon.Visible = $false
        $notifyIcon.Dispose()
    } catch {}

    try {
        $form.Close()
    } catch {}
}

function Enable-ModernWindowChrome {
    try {
        $cornerPreference = 2
        [VGT.SleepTimer.WindowNative]::DwmSetWindowAttribute($form.Handle, 33, [ref]$cornerPreference, 4) | Out-Null
    } catch {}

    try {
        $darkMode = 1
        [VGT.SleepTimer.WindowNative]::DwmSetWindowAttribute($form.Handle, 20, [ref]$darkMode, 4) | Out-Null
    } catch {}
}

$dragWindow = {
    param($sender, $eventArgs)

    if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        [VGT.SleepTimer.WindowNative]::ReleaseCapture() | Out-Null
        [VGT.SleepTimer.WindowNative]::SendMessage(
            $form.Handle,
            [VGT.SleepTimer.WindowNative]::WM_NCLBUTTONDOWN,
            [VGT.SleepTimer.WindowNative]::HT_CAPTION,
            0
        ) | Out-Null
    }
}

$header.Add_MouseDown($dragWindow)
$titleLabel.Add_MouseDown($dragWindow)
$accentDiamond.Add_MouseDown($dragWindow)
$modeLabel.Add_MouseDown($dragWindow)

$btnHide.Add_MouseEnter({
    $btnHide.ForeColor = New-Color '#00FFCC'
})
$btnHide.Add_MouseLeave({
    $btnHide.ForeColor = New-Color '#7C8798'
})
$btnHide.Add_Click({
    Hide-TimerWindow
})

$btnClose.Add_MouseEnter({
    $btnClose.BackColor = New-Color '#B91C1C'
    $btnClose.ForeColor = New-Color '#FFFFFF'
})
$btnClose.Add_MouseLeave({
    $btnClose.BackColor = [System.Drawing.Color]::Transparent
    $btnClose.ForeColor = New-Color '#7C8798'
})
$btnClose.Add_Click({
    Stop-TimerAndClose -ShowMessage $true
})

$hideButton.Add_Click({
    Hide-TimerWindow
})

$cancelButton.Add_Click({
    Stop-TimerAndClose -ShowMessage $true
})

$setButton.Add_Click({
    $requestedSeconds = Get-RequestedSeconds

    if ($null -eq $requestedSeconds) {
        return
    }

    Set-TimerDuration -Seconds $requestedSeconds

    if (-not $timer.Enabled) {
        $timer.Start()
    }

    $statusLabel.Text = 'RESTZEIT AKTUALISIERT'
    $statusLabel.ForeColor = $statusAccentColor
})

$plusButton.Add_Click({
    $nextSeconds = [Math]::Min($script:remainingSeconds + 900, $MaxSeconds)
    Set-TimerDuration -Seconds $nextSeconds
    $statusLabel.Text = '+15 MINUTEN GESETZT'
    $statusLabel.ForeColor = $statusAccentColor
})

$minusButton.Add_Click({
    $nextSeconds = [Math]::Max($script:remainingSeconds - 900, $MinSeconds)
    Set-TimerDuration -Seconds $nextSeconds
    $statusLabel.Text = '-15 MINUTEN GESETZT'
    $statusLabel.ForeColor = $statusAccentColor
})

$menuShowHide.Add_Click({
    Toggle-TimerWindow
})

$menuSetVisible.Add_Click({
    Show-TimerWindow
})

$menuCancel.Add_Click({
    Stop-TimerAndClose -ShowMessage $true
})

$notifyIcon.Add_DoubleClick({
    Toggle-TimerWindow
})

$timer.Add_Tick({
    if ($script:isTerminating) {
        return
    }

    $script:remainingSeconds = [Math]::Max(0, $script:remainingSeconds - 1)

    if ($script:remainingSeconds -le 0) {
        Invoke-SystemSleep
        return
    }

    if ($statusLabel.ForeColor.ToArgb() -ne $statusNeutralArgb) {
        $statusLabel.Text = 'ACTIVE TIMER · RESTZEIT LIVE ÄNDERBAR'
        $statusLabel.ForeColor = $statusNeutralColor
    }

    Update-Display
})

$form.Add_Shown({
    Enable-ModernWindowChrome
    Set-TimerDuration -Seconds $script:totalSeconds
    $timer.Start()
})

$form.Add_FormClosing({
    if (-not $script:isTerminating) {
        $script:isTerminating = $true

        try {
            $timer.Stop()
        } catch {}
    }

    try {
        $notifyIcon.Visible = $false
        $notifyIcon.Dispose()
    } catch {}
})

[void][System.Windows.Forms.Application]::Run($form)
