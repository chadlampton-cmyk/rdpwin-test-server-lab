# Handoff

Last updated: 2026-04-15.

## Cold-Start Instruction

Read this file first after reboot. This repo is the temporary `RDPWin` lab repo,
not the production AVD repo.

Stay in:

`/Users/chad.lampton/Documents/repo/rdpwin-test-server-lab`

## Current Lab Shape

- discovery session host:
  - Azure VM: `rdp-discovery-01`
  - Windows name: `RDPDISC01`
- backend DB/file server:
  - Azure VM: `db-test-01`
  - Windows name: `DBTEST01`
  - private IP: `10.210.10.5`
  - data root: `F:\RDPDiscovery`
- Azure control plane:
  - subscription: `platform-sandbox`
  - resource group: `rg-rdp-discovery-test`
  - host pool: `hp-rdp-discovery-test`
  - workspace: `ws-rdp-discovery-test`
  - RemoteApp group: `rag-rdp-discovery-test`
  - desktop group: `dag-rdp-discovery-test`

## What Is Installed And Working

- `DBTEST01` is deployed and bootstrapped.
- `DBTEST01` exposes:
  - `\\DBTEST01\RDPAPPS$`
  - `\\DBTEST01\RDPCONFIG$`
  - `\\DBTEST01\RDPDATA$`
- `RDPDISC01` can browse those three shares.
- `RDPDISC01` and `DBTEST01` both have `AADLoginForWindows` installed and
  succeeded.
- Entra VM login RBAC is present on both VMs for
  `chad.lampton@fullsteamhosted.com`.
- `RDPWin` is installed on `RDPDISC01`.
- `RDPWin` works from a full desktop session on `RDPDISC01`.

## Important AVD Findings

- AVD access was repaired on 2026-04-14.
- Root cause:
  - `RDPDISC01` was missing the `Remote Desktop Session Host` role
    (`RDS-RD-Server`)
  - AVD SxS stack installation was failing because of that
- Repair completed:
  - installed `RDS-RD-Server`
  - restarted `RDPDISC01`
- Current AVD health:
  - session host status: `Available`
  - session host update state: `Succeeded`

## Current Access Model

- admin path:
  - Bastion or equivalent direct admin path
  - use `localadmin` for maintenance/troubleshooting
- AVD / Windows App path:
  - workspace friendly name: `RDP Discovery Test Workspace`
  - current host pool preferred app group type: `RailApplications`
  - `chad.lampton@fullsteamhosted.com` currently has:
    - `Desktop Virtualization User` on `rag-rdp-discovery-test`
    - no desktop entitlement on `dag-rdp-discovery-test`

This means the current Entra user experience is intentionally app-only, not
desktop-first.

## Most Important Current Limitation

Pure RemoteApp is not yet usable for `RDPWin`.

Current observed behavior:

- Windows App feed now shows the `RDPWin` RemoteApp correctly
- selecting the app reaches Windows `Welcome`
- the user profile loads successfully
- the session logs off almost immediately afterward
- `RDPWin` works from a full AVD desktop session, but not as a pure RemoteApp

Interpretation:

- Entra login is working
- AVD brokering is working
- profile load is working
- the remaining failure is `RDPWin` behavior in pure RemoteApp mode

## Working Assumption

The most likely viable model is now:

- AVD desktop session for the user path
- local policy / scripted session shaping on `RDPDISC01`
- auto-launch `RDPWin` at logon
- make the session feel app-like
- log off the session when `RDPWin` closes

This is closer to the current TERM-server behavior than Bastion, and is more
realistic than forcing pure RemoteApp if `RDPWin` is not RemoteApp-clean.

## Repo State

Repo-local automation now supports:

- pooled AVD host pool
- RemoteApp group for `RDPWin`
- desktop app group for desktop-session testing
- workspace association to both app groups
- AVD user RBAC assignment support
- VM login RBAC assignment support

Files that were updated for the new AVD model:

- `terraform/`
- `inventories/group_vars/all.yml`
- `roles/lab_tofu/tasks/main.yml`
- `README.md`
- `docs/RUNBOOK.md`
- `docs/TEST_PLAN.md`
- `docs/ARCHITECTURE.md`
- `docs/VALIDATION.md`

## What Was Verified Recently

- `az` confirmed:
  - `rdp-discovery-01-aadlogin` succeeded
  - `db-test-01-aadlogin` succeeded
  - VM login RBAC is present for `chad.lampton@fullsteamhosted.com`
  - Bastion SKU is still `Developer`
- AVD control plane confirmed:
  - workspace `ws-rdp-discovery-test` exists
  - desktop group `dag-rdp-discovery-test` exists
  - RemoteApp group `rag-rdp-discovery-test` exists
  - `RDPWin` is published from
    `C:\ProgramData\ResortDataProcessing\RDPWin\RDPWin5Client\RDPWin.exe`
- Event logs confirmed:
  - RDS logon/profile load succeeds for the test user
  - pure RemoteApp session exits immediately after logon

## Next Recommended Work

Do not spend time on more Terraform scaffolding first.

The next meaningful work is:

1. restore desktop entitlement temporarily for the test Entra user
2. validate the AVD desktop path again through Windows App
3. configure `RDPDISC01` to auto-launch `RDPWin` at user logon
4. shape the desktop session to behave like an app session
5. add logoff behavior when `RDPWin` closes
6. only revisit pure RemoteApp later if the desktop-shaped model is insufficient

## Probe Guidance

The probe remains useful for install/config drift checks, but it is not the
current blocker. The current blocker is session behavior after AVD sign-in.

Probe path on the Windows host:

`C:\Temp\Invoke-RDPWinLabProbe.ps1`

## Related Repos

- production AVD repo:
  - `/Users/chad.lampton/Documents/repo/rdp-avd-fshosted`
- SAW reference repo:
  - `/Users/chad.lampton/Documents/repo/saw-avd-fshosted`
- discovery notes:
  - `/Users/chad.lampton/Documents/rdp-soft-discovery`
