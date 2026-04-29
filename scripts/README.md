# Scripts

Windows-side lab helpers for the temporary `RDPWin` test server.

## RDPWin Lab Probe

Copy `scripts/Invoke-RDPWinLabProbe.ps1` to
`C:\Temp\Invoke-RDPWinLabProbe.ps1` on the test Windows host.

Baseline example:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File C:\Temp\Invoke-RDPWinLabProbe.ps1 -Phase Baseline -TargetHosts DBTEST01 -SharePaths '\\DBTEST01\RDPAPPS$','\\DBTEST01\RDPCONFIG$','\\DBTEST01\RDPDATA$'
```

After install/config example:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File C:\Temp\Invoke-RDPWinLabProbe.ps1 -Phase AfterRDPWinInstall -TargetHosts DBTEST01 -SharePaths '\\DBTEST01\RDPAPPS$','\\DBTEST01\RDPCONFIG$','\\DBTEST01\RDPDATA$' -InstallerPaths 'C:\Install\RDPWinMSI_5.6.001.6.msi'
```

Launch smoke-test monitor example:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File C:\Temp\Invoke-RDPWinLabProbe.ps1 -Phase LaunchSmoke -TargetHosts DBTEST01 -SharePaths '\\DBTEST01\RDPAPPS$','\\DBTEST01\RDPCONFIG$','\\DBTEST01\RDPDATA$' -MonitorRDPWinSeconds 180
```

RemoteApp crash-debug example:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File C:\Temp\Invoke-RDPWinLabProbe.ps1 -Phase LaunchSmoke -TargetHosts DBTEST01 -SharePaths '\\DBTEST01\RDPNT1000','\\DBTEST01\RDPNT2000','\\DBTEST01\RDPNT3000' -MonitorRDPWinSeconds 180 -EnableLocalDumps -CrashEventLookbackHours 6
```

The crash-debug path now also:

- checks both likely `RDPWin.exe` locations
- inventories `WER` local-dump configuration and any captured dumps for
  `RDPWin.exe`
- collects recent `Application` log crash events for `RDPWin`, `Resort`,
  `Actian`, `Zen`, and `Pervasive` strings

By default the probe writes to:

```text
C:\Temp\RDPWinLab\<COMPUTERNAME>\<Phase>_<timestamp>
```

The probe is read-only except for creating its output directory and output files.

## DBTEST01 Layout Builder

Use `scripts/New-DBTEST01Layout.ps1` with `config/dbtest01-layout.json` to
create the baseline folder structure for the planned `DBTEST01` discovery
database and file server.

Default repo layout root:

```text
F:\RDPDiscovery
```

`F:` is preferred because Azure Windows VMs commonly reserve `D:` for the
temporary disk.

Preview only:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\New-DBTEST01Layout.ps1 -WhatIf
```

Create folders:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\New-DBTEST01Layout.ps1
```

Create folders and hidden SMB shares:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\New-DBTEST01Layout.ps1 -CreateShares
```

## Desktop Experience Scaffold

Use `scripts/Configure-RDPWinDesktopExperience.ps1` to scaffold the current
desktop-session policy experiment on `RDPDISC01`.

What it does:

- writes `C:\ProgramData\RDPWinLab\Start-RDPWinDesktop.ps1`
- writes `C:\ProgramData\RDPWinLab\SessionPolicy.json`
- writes `C:\ProgramData\RDPWinLab\AppLocker\RDPWinLab-AppLocker.xml`
- registers per-user Scheduled Tasks only for the configured restricted users
- auto-launches `RDPWin` for matched non-admin users
- logs off the session when `RDPWin` closes
- applies opt-in HKCU Explorer policy settings for the `CSS`, `HSC`, and `TCS`
  user patterns from `config/rdpwin-session-policy.json`
- creates a local group for restricted lab users and scaffolds an AppLocker
  policy so Start can remain present while non-admin launch surfaces are
  constrained without replacing `explorer.exe`

Example:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\Configure-RDPWinDesktopExperience.ps1
```

Optional explicit config path:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\Configure-RDPWinDesktopExperience.ps1 -PolicyConfigPath .\..\config\rdpwin-session-policy.json
```

Important note:

- this is a scaffold for taskbar/Start-menu restriction testing, not proof that
  Windows will fully block left-click Start or hide every shell surface cleanly
- the safer default keeps `AppLocker.Enabled` off unless explicitly turned on in
  `config/rdpwin-session-policy.json`
- even when `AppLocker.Enabled` is on, the script now forces `AuditOnly` unless
  `AppLocker.AllowEnforcedMode` is explicitly set to `true` in the policy JSON
- the repo’s current design history still says aggressive shell lockdown can
  destabilize `RDPWin`, so treat these policy values as experiment flags rather
  than a final control model
- the AppLocker scaffold defaults to `AuditOnly`; move to `Enforced` only after
  reviewing the AppLocker event logs and confirming the allowed path set is
  sufficient for `RDPWin` and the session shell dependencies
- the current AppLocker targeting model uses explicit `RestrictedUserAccounts`
  entries in `config/rdpwin-session-policy.json`; if the lab expands beyond
  `CSS0`, `HSC1`, and `TCS2`, add those accounts before deployment
