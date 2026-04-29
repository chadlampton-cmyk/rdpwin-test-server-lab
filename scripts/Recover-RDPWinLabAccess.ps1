<#
.SYNOPSIS
  Emergency recovery: disable AppLocker enforcement and remove RDPWinLab logon automation.

.DESCRIPTION
  Use when tight AppLocker or the desktop launcher prevents any interactive
  session (Bastion, AVD, or direct RDP). Run from Azure VM Run Command as
  PowerShell if you cannot open a session on the VM.
#>
$ErrorActionPreference = 'Stop'

Stop-Service -Name 'AppIDSvc' -Force -ErrorAction SilentlyContinue
Set-Service -Name 'AppIDSvc' -StartupType Disabled -ErrorAction SilentlyContinue

$taskPath = '\RDPWinLab\'
$taskName = 'RDPWin Desktop Launcher'
Unregister-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Get-ScheduledTask -TaskPath $taskPath -ErrorAction SilentlyContinue |
    Where-Object { $_.TaskName -like "$taskName*" } |
    ForEach-Object {
        Unregister-ScheduledTask -TaskPath $_.TaskPath -TaskName $_.TaskName -Confirm:$false -ErrorAction SilentlyContinue
    }

$runKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
Remove-ItemProperty -Path $runKey -Name 'RDPWinDesktopLauncher' -ErrorAction SilentlyContinue

Write-Output 'Recovery complete: AppIDSvc disabled; RDPWinLab scheduled task and Run key removed. Reboot recommended before re-applying Configure-RDPWinDesktopExperience.ps1 with safe policy JSON.'
