# RDPWin Test Plan

## Goal

Prove the smallest repeatable build needed for `RDPWin` on a fresh Windows host
with an Azure-hosted backend, then shape the user session so it behaves like the
current TERM-server experience.

Use `DBTEST01` as the temporary Azure backend rather than rebuilding retained
`DB01` or `DB02`.

## Current Test Result Summary

Already proven:

- `RDPDISC01` can reach `DBTEST01` over the required UNC/share paths
- `RDPWin` is installed on `RDPDISC01`
- `RDPWin` works from a full desktop session
- AVD access to `RDPDISC01` now works through Windows App
- the temporary Zen license on `DBTEST01` was reactivated and
  `Btrieve Error 161` cleared

Not yet proven:

- whether the desktop-shaped session model is stable enough without extra shell
  lockdown
- whether any remaining backend/app issue appears after the license fix under
  normal desktop-session usage

Current evidence says pure RemoteApp is not viable for this app, and the active
test direction is now the desktop-session-shaped model.

## Test Sequence

### 1. Backend Baseline

Before changing user-session behavior, confirm the backend assumptions still
hold:

- `DBTEST01` is running
- `RDPDISC01` can reach:
  - `\\DBTEST01\RDPAPPS$`
  - `\\DBTEST01\RDPCONFIG$`
  - `\\DBTEST01\RDPDATA$`

Run the probe as needed from the Windows host:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File C:\Temp\Invoke-RDPWinLabProbe.ps1 -Phase Baseline -TargetHosts DBTEST01 -SharePaths '\\DBTEST01\RDPAPPS$','\\DBTEST01\RDPCONFIG$','\\DBTEST01\RDPDATA$'
```

### 2. Desktop Session Validation

Use Windows App to enter the AVD desktop session on `RDPDISC01`.

Confirm:

- Windows sign-in succeeds
- `RDPWin` launches automatically or manually from the desktop session
- app-side sign-in behavior is captured
- any backend error text is recorded precisely

### 3. App-Session Shaping

Target the current-like user experience:

- user signs into Windows App
- the session lands on `RDPDISC01`
- `RDPWin` opens automatically
- the user interacts with `RDPWin`, not the desktop
- closing `RDPWin` logs off the session

This phase now uses local policy, registry, and scripted logon/session behavior
on `RDPDISC01`.

Guardrails from current testing:

- keep `explorer.exe` alive
- do not pursue shell replacement yet
- do not pursue aggressive Start/taskbar restrictions first
- `Server Manager` suppression and logoff-on-close are acceptable
- left-click-only Start suppression does not have a clean supported local GPO

### 4. Validate Session End Behavior

Confirm whether closing `RDPWin`:

- logs off the session immediately
- disconnects the session
- or leaves the desktop available

If the default behavior is wrong, tune it with session policy rather than
returning to pure RemoteApp first.

### 5. Backend Validation After Desktop Launch

After `RDPWin` launches from the desktop session, validate the backend state on
`DBTEST01`.

Current known backend findings:

- `Actian Zen Cloud Server` is running
- `RDPWin Monitor GDS Reservations` is running
- the Zen temporary license was confirmed expired, then reactivated
- `Btrieve Error 161` is no longer the active blocker
- pure RemoteApp still fails even after the license fix

This means the main design decision is settled: keep the desktop model and stop
treating RemoteApp as the target path.

## Evidence To Keep

Keep outside git unless scrubbed:

- screenshots
- Windows App behavior notes
- exact `RDPWin` login error text
- installer filenames/checksums
- probe output
- any local policy or registry changes made during session-shaping tests

Suggested local-only workspace:

```text
local/
```

## Success Criteria

- `RDPWin` works against the Azure-side backend on `RDPDISC01`
- the user path is entered through Windows App / AVD
- the user experience behaves like an app-first term-server session
- the desktop remains technically present but is no longer the practical user
  surface
- session end behavior after closing `RDPWin` is known and documented
- the resulting configuration is scriptable for future scale-out
