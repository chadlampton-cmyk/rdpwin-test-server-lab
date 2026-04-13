# Tomorrow Test Checklist

## Purpose

This is the short operator checklist for the next `RDPWin` lab session.

Use this when the goal is to run the test cleanly without spending time
rediscovering context during the session.

## What Tomorrow Is Trying To Prove

Tomorrow is not just an installer test.

It is a controlled check of both:

- Windows/session-host access on `RDPDISC01`
- application/backend/share access between `RDPDISC01` and `DBTEST01`

The environment is only useful if both layers work.

## Before You Start

Confirm these are still true:

- `RDPDISC01` exists and is reachable through the current admin path
- `DBTEST01` exists and is running
- `DBTEST01` still has:
  - `\\DBTEST01\RDPAPPS$`
  - `\\DBTEST01\RDPCONFIG$`
  - `\\DBTEST01\RDPDATA$`
- the test operator can still access both VMs
- the install media is still available in:
  - `/Users/chad.lampton/Documents/RDPInstalls/TermServers/`
- `C:\Temp\Invoke-RDPWinLabProbe.ps1` is present on `RDPDISC01`

## Preflight On The Servers

On `DBTEST01`, confirm the shares still exist:

```cmd
net share RDPAPPS$
net share RDPCONFIG$
net share RDPDATA$
```

On `RDPDISC01`, confirm backend reachability still works:

```cmd
dir \\DBTEST01\RDPAPPS$
dir \\DBTEST01\RDPCONFIG$
dir \\DBTEST01\RDPDATA$
```

If those fail, stop and resolve that first. Do not start the install sequence
until backend share access is confirmed.

## Install Order

Current recommended first-pass install order on `RDPDISC01`:

1. `VC_redist.x64.exe`
2. `VC_redist.x86.exe`
3. `CRRuntime_64bit_13_0_39.msi`
4. `Zen_Patch_Client-16.11.006.000.exe`
5. `RDPWinMSI_5.6.001.6.msi`

Do not begin with `RDPInterfaces`, `RDPKeyCard`, web-tier packages, or
server-side `RDPWin` packages unless the first-pass client install fails and
the failure clearly points there.

## Probe Commands

Run the probe on `RDPDISC01` at each milestone.

Baseline:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File C:\Temp\Invoke-RDPWinLabProbe.ps1 -Phase Baseline -TargetHosts DBTEST01 -SharePaths '\\DBTEST01\RDPAPPS$','\\DBTEST01\RDPCONFIG$','\\DBTEST01\RDPDATA$'
```

After Actian/client prerequisites:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File C:\Temp\Invoke-RDPWinLabProbe.ps1 -Phase AfterActian -TargetHosts DBTEST01 -SharePaths '\\DBTEST01\RDPAPPS$','\\DBTEST01\RDPCONFIG$','\\DBTEST01\RDPDATA$'
```

After `RDPWin` install:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File C:\Temp\Invoke-RDPWinLabProbe.ps1 -Phase AfterRDPWinInstall -TargetHosts DBTEST01 -SharePaths '\\DBTEST01\RDPAPPS$','\\DBTEST01\RDPCONFIG$','\\DBTEST01\RDPDATA$'
```

After any manual config changes:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File C:\Temp\Invoke-RDPWinLabProbe.ps1 -Phase AfterConfig -TargetHosts DBTEST01 -SharePaths '\\DBTEST01\RDPAPPS$','\\DBTEST01\RDPCONFIG$','\\DBTEST01\RDPDATA$'
```

Launch smoke test:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File C:\Temp\Invoke-RDPWinLabProbe.ps1 -Phase LaunchSmoke -TargetHosts DBTEST01 -SharePaths '\\DBTEST01\RDPAPPS$','\\DBTEST01\RDPCONFIG$','\\DBTEST01\RDPDATA$' -MonitorRDPWinSeconds 180
```

## What To Check After Install

On `RDPDISC01`, confirm whether these exist after `RDPWin` install:

- `C:\ProgramData\ResortDataProcessing\RDPWin`
- `C:\ProgramData\ResortDataProcessing\RDPWin\GroupToServer5.txt`
- `C:\ProgramData\ResortDataProcessing\RDPWin\RDPWinPath5.txt`
- `C:\ProgramData\ResortDataProcessing\RDPWin\RDPWin5Client\RDPWin.exe`

Also check:

- installed software entries
- ODBC drivers and DSNs
- any new services
- any shortcuts or launcher files

## Success Criteria

Tomorrow is a successful session if you leave with answers to these:

- does the fresh host install the client prerequisites cleanly
- does the fresh host install `RDPWin` cleanly
- does `RDPWin.exe` exist in the expected path
- does first launch work at all
- if launch fails, is the blocker clearly install, config, auth, DB, or share
  related

## Likely Blockers

The main risks are now application-side, not Azure-side:

- missing config files
- missing ODBC or Actian details
- backend shares exist but required files are not present
- AD-group-driven path selection is still needed for first successful launch
- app-side credentials or test data are incomplete

## If Something Fails

Record the exact failure immediately:

- screenshot
- exact installer name and version
- exact command used
- exact error text
- which phase failed
- whether the failure is before launch, during login, or after backend contact

Do not rely on memory after the session.

## Related Notes

- [CURRENT_STATE.md](./CURRENT_STATE.md)
- [TEST_PLAN.md](./TEST_PLAN.md)
- [RUNBOOK.md](./RUNBOOK.md)
- [HANDOFF.md](./HANDOFF.md)
