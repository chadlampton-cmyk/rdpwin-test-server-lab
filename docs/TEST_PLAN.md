# RDPWin Test Plan

## Goal

Prove the smallest repeatable build needed for `RDPWin` on a fresh Windows host
with an Azure-hosted backend that stays as Entra-centered as possible.

This lab is for learning the session-host/application side first. Do not clone
an existing `TERM` server. Use `DBTEST01` as the temporary Azure backend rather
than rebuilding retained `DB01` or `DB02`.

## Test Sequence

### 1. Fresh Host Baseline

Before installing `RDPWin` or Actian, access the deployed Windows host through Bastion and run the lab probe:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\scripts\Invoke-RDPWinLabProbe.ps1 -Phase Baseline -TargetHosts DB01,DB02
```

Capture whether the host is workgroup/domain/Entra joined, which DNS servers it
uses, whether `DBTEST01` resolves, and whether required backend ports are
reachable for the approved non-production test path.

### 0. Backend Bootstrap

Before application testing, deploy and bootstrap `DBTEST01`:

```bash
ansible-playbook playbooks/deploy_lab.yml
ansible-playbook playbooks/configure_dbserver.yml
```

Confirm the backend layout exists on `DBTEST01` and that the session host can
reach the intended UNC paths.

### 2. Actian Client Install

Install the approved Actian / Zen client package for the lab test path.

Run:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\scripts\Invoke-RDPWinLabProbe.ps1 -Phase AfterActian -TargetHosts DB01,DB02
```

Capture installed product version, services, ODBC drivers, ODBC DSNs, and connectivity.

If installer files are local on the test host, pass them with `-InstallerPaths` so the output includes size and SHA-256 checksum.

### 3. RDPWin Install

Install the authoritative `RDPWin` package from an out-of-git location after the correct package is received from the named installer owner.

Run:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\scripts\Invoke-RDPWinLabProbe.ps1 -Phase AfterRDPWinInstall -TargetHosts DB01,DB02
```

Confirm whether these exist:

- `C:\ProgramData\ResortDataProcessing\RDPWin`
- `C:\ProgramData\ResortDataProcessing\RDPWin\GroupToServer5.txt`
- `C:\ProgramData\ResortDataProcessing\RDPWin\RDPWinPath5.txt`
- `C:\ProgramData\ResortDataProcessing\RDPWin\RDPWin5Client\RDPWin.exe`

### 4. Minimum Config

Apply only the config needed to make the approved non-production test path work.

Record every manual change in `local/` or `docs/OBSERVATIONS.md` before converting it to automation.

Run:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\scripts\Invoke-RDPWinLabProbe.ps1 -Phase AfterConfig -TargetHosts DB01,DB02
```

### 5. First Launch Test

Start the monitor, launch `RDPWin.exe` manually, sign in with the approved Azure test user and app-side test identity if separate, perform a narrow smoke test, close the application, then let the monitor complete:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\scripts\Invoke-RDPWinLabProbe.ps1 -Phase LaunchSmoke -TargetHosts DB01,DB02 -MonitorRDPWinSeconds 180
```

Capture whether login succeeds, which backend is reached, whether obvious errors appear, whether printing can be tested, and what profile or ProgramData files change.

## Evidence To Keep

Keep probe output, screenshots, installer filenames/checksums, manual install commands, and human observations outside git unless they are scrubbed.

Suggested local-only workspace:

```text
local/
```

## Success Criteria

- Fresh host can install the chosen Actian client.
- Fresh host can install the chosen `RDPWin` package.
- `RDPWin.exe` launches from the confirmed production-style path.
- Required config files/settings are identified.
- Required backend, UNC, DNS, auth, and port dependencies are identified.
- `DBTEST01` successfully hosts the temporary Azure backend folder/share layout.
- The approved non-production test identity can attempt a meaningful application login.
- The team knows whether the test hit `DBTEST01`, a retained path, or another target.
- A short punch list exists for anything not ready for AVD image automation.
