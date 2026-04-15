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

Not yet proven:

- whether `RDPWin` can run cleanly as a pure RemoteApp
- whether the production-like user experience should instead be:
  - AVD desktop session
  - auto-launch `RDPWin`
  - log off when `RDPWin` closes

Current evidence says pure RemoteApp is failing after logon, so the next test
direction should favor the desktop-session-shaped model.

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
- `RDPWin` launches manually from the installed path
- app-side sign-in works as expected

### 3. App-Session Shaping

Target the current-like user experience:

- user signs into Windows App
- the session lands on `RDPDISC01`
- `RDPWin` opens automatically
- the user interacts with `RDPWin`, not the desktop
- closing `RDPWin` logs off the session

This phase is expected to use local policy, registry, or scripted logon/session
behavior on `RDPDISC01`.

### 4. Validate Session End Behavior

Confirm whether closing `RDPWin`:

- logs off the session immediately
- disconnects the session
- or leaves the desktop available

If the default behavior is wrong, tune it with session policy rather than
returning to pure RemoteApp first.

## Evidence To Keep

Keep outside git unless scrubbed:

- screenshots
- Windows App behavior notes
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
- the desktop is no longer the primary user surface
- session end behavior after closing `RDPWin` is known and documented
- the resulting configuration is scriptable for future scale-out
