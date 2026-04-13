# Scripts

Windows-side lab helpers for the temporary `RDPWin` test server.

## RDPWin Lab Probe

Copy the repo or the `scripts/Invoke-RDPWinLabProbe.ps1` file to the test Windows host.

Baseline example:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\Invoke-RDPWinLabProbe.ps1 -Phase Baseline -TargetHosts DB01,DB02
```

After install/config example:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\Invoke-RDPWinLabProbe.ps1 -Phase AfterRDPWinInstall -TargetHosts DB01,DB02 -SharePaths '\\10.35.52.108\RDPNT3571','\\10.35.52.108\RDPNT3803' -InstallerPaths 'C:\Install\RDPWin.msi'
```

Launch smoke-test monitor example:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\Invoke-RDPWinLabProbe.ps1 -Phase LaunchSmoke -TargetHosts DB01,DB02 -MonitorRDPWinSeconds 180
```

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
