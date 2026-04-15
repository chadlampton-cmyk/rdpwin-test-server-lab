# Tomorrow Test Checklist

## Purpose

This is the short local-only checklist for the next `RDPWin` lab session.

Use it when the goal is to continue from the current AVD desktop model without
rediscovering context during the session.

## What Tomorrow Is Trying To Prove

The next test is no longer “can we publish pure RemoteApp,” and it is no longer
“can we hack the shell harder.”

The next test is:

- can a non-admin Entra user enter `RDPDISC01` through Windows App / AVD
- can `RDPWin` launch deterministically at logon for that user
- can closing `RDPWin` end the session with a full logoff
- can the launch mechanism work consistently across users, not just Chad
- can the next control layer move toward PCI-aligned routing and auditability

## Before You Start

Confirm these are still true:

- `RDPDISC01` exists and is `Available` in the AVD host pool
- `DBTEST01` exists and is running
- `DBTEST01` still has:
  - `\\DBTEST01\RDPAPPS$`
  - `\\DBTEST01\RDPCONFIG$`
  - `\\DBTEST01\RDPDATA$`
- the Zen license on `DBTEST01` is still active
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
- the active path is now the desktop session that should auto-launch `RDPWin`
- `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run` is not reliable enough
  for the launcher
- `AzureAD\\ChadLampton` logged launcher activity
- `felix.ferdinand@fullsteamhosted.com` did not hit the launcher at all
- `explorer.exe` must stay alive
- Bastion remains the admin path, not the user-path test

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

1. Replace the current `HKLM Run` launcher with a Scheduled Task at user logon.
2. Keep the current launcher logic simple:
   - admin users bypass app shaping
   - non-admin users launch `RDPWin`
   - app exit triggers full `logoff`
3. Retest with `felix.ferdinand@fullsteamhosted.com` as the primary non-admin
   user.
4. Confirm Felix sees the AVD desktop and that `RDPWin` launches at sign-in.
5. Confirm closing `RDPWin` ends the session with full logoff, not disconnect.
6. Do not add new shell-kill, shell-replacement, or Start/taskbar lockdown
   changes during the same test pass.
7. Define the Entra group model for DB routing:
   - one group per DB target
   - fail closed on missing or ambiguous membership
8. Start the local routing-broker design on `RDPDISC01` so users do not browse
   or choose DB paths directly.
9. Capture every policy, registry, script, task, and AVD entitlement change.

## Likely Blockers

- `RDPWin` may assume a full desktop shell
- `HKLM Run` is not a reliable trigger across all Entra/AVD users
- app-side credentials or test data may still be incomplete
- per-user DB routing is not implemented yet
- unsupported Start/taskbar suppression ideas may look attractive but are not a
  clean supported path
- trying to solve UX and routing in the same change set will make failures
  harder to isolate

## PCI-Alignment Guardrails

Keep the next session inside these guardrails:

- use separate admin and non-admin identities
- keep AVD desktop as the user path
- keep `explorer.exe` alive
- prefer deterministic and auditable controls over shell hacks
- do not let users browse raw DB paths
- treat Entra security groups as the routing source of truth
- fail closed if user-to-DB routing is missing or ambiguous

## If Something Fails

Record the exact failure immediately:

- screenshot
- exact Windows App behavior
- exact error text
- whether the failure is before logon, after `Welcome`, at `RDPWin` launch, or
  after app sign-in
- exact server-side change made before the failure
- whether the Scheduled Task triggered
- whether `DesktopLaunch.log` shows the user
- whether the failure affects only one Entra user or all non-admin users

## Related Notes

- [CURRENT_STATE.md](./CURRENT_STATE.md)
- [TEST_PLAN.md](./TEST_PLAN.md)
- [RUNBOOK.md](./RUNBOOK.md)
- [HANDOFF.md](./HANDOFF.md)
- [PCI_ALIGNMENT_PLAN.md](./PCI_ALIGNMENT_PLAN.md)
- [ACCESS_AND_ROUTING_PLAN.md](./ACCESS_AND_ROUTING_PLAN.md)
