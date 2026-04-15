# Tomorrow Test Checklist

## Purpose

This is the short operator checklist for the next `RDPWin` lab session.

Use it when the goal is to continue from the current repaired AVD state without
rediscovering context during the session.

## What Tomorrow Is Trying To Prove

The next test is no longer “can we publish pure RemoteApp.”

The next test is:

- can a user enter `RDPDISC01` through Windows App / AVD
- can the session behave like an app-first TERM session
- can `RDPWin` auto-launch cleanly in that desktop session
- can closing `RDPWin` end the session cleanly
- can that happen without destabilizing `RDPWin` through shell lockdown

## Before You Start

Confirm these are still true:

- `RDPDISC01` exists and is `Available` in the AVD host pool
- `DBTEST01` exists and is running
- `DBTEST01` still has:
  - `\\DBTEST01\RDPAPPS$`
  - `\\DBTEST01\RDPCONFIG$`
  - `\\DBTEST01\RDPDATA$`
- the test operator can still use:
  - Windows App for the user path
  - `localadmin` for the admin path
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

If those fail, stop and resolve that first.

## Current AVD Facts

Keep these in mind:

- pure `RDPWin` RemoteApp currently fails after logon
- full desktop session works
- the Zen license issue was fixed and did not change the RemoteApp result
- the active path is now the desktop session that auto-launches `RDPWin`

## Probe Commands

Run the probe from `RDPDISC01` only when you need install/config evidence.

Baseline:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File C:\Temp\Invoke-RDPWinLabProbe.ps1 -Phase Baseline -TargetHosts DBTEST01 -SharePaths '\\DBTEST01\RDPAPPS$','\\DBTEST01\RDPCONFIG$','\\DBTEST01\RDPDATA$'
```

After config changes:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File C:\Temp\Invoke-RDPWinLabProbe.ps1 -Phase AfterConfig -TargetHosts DBTEST01 -SharePaths '\\DBTEST01\RDPAPPS$','\\DBTEST01\RDPCONFIG$','\\DBTEST01\RDPDATA$'
```

Launch smoke:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File C:\Temp\Invoke-RDPWinLabProbe.ps1 -Phase LaunchSmoke -TargetHosts DBTEST01 -SharePaths '\\DBTEST01\RDPAPPS$','\\DBTEST01\RDPCONFIG$','\\DBTEST01\RDPDATA$' -MonitorRDPWinSeconds 180
```

## Next Session Tasks

1. restore desktop entitlement for the test Entra user if needed
2. enter `RDPDISC01` through Windows App
3. confirm `RDPWin` auto-launches in the desktop session
4. test whether closing `RDPWin` logs off the session
5. avoid new shell-kill or Start/taskbar lockdown experiments first
6. capture every policy, registry, or startup-script change

## Likely Blockers

- `RDPWin` may assume a full desktop shell
- app-side credentials or test data may still be incomplete
- AD-group-driven path selection may still be required later
- unsupported Start/taskbar suppression ideas may look attractive but are not a
  clean supported path

## If Something Fails

Record the exact failure immediately:

- screenshot
- exact Windows App behavior
- exact error text
- whether the failure is before logon, after `Welcome`, at `RDPWin` launch, or
  after app sign-in
- exact server-side change made before the failure

## Related Notes

- [CURRENT_STATE.md](./CURRENT_STATE.md)
- [TEST_PLAN.md](./TEST_PLAN.md)
- [RUNBOOK.md](./RUNBOOK.md)
- [HANDOFF.md](./HANDOFF.md)
