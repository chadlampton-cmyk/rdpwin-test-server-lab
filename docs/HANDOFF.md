# Handoff

Last updated: 2026-04-17.

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
  - historical subscription: `platform-sandbox`
  - resource group: `rg-rdp-discovery-test`
  - host pool: `hp-rdp-discovery-test`
  - workspace: `ws-rdp-discovery-test`
  - RemoteApp group: `rag-rdp-discovery-test`
  - desktop group: `dag-rdp-discovery-test`
- active retargeting direction:
  - tenant: `fscaptest.onmicrosoft.com`
  - subscription: `FS Capabilities - Test External AVD`
  - subscription ID: `56bf2a01-7815-4df3-a396-b9b4d6a55362`
  - test operator UPN: `chad.lampton@fullsteamtest.onmicrosoft.com`

## Current Active Deployment

The repo is no longer only in retargeting mode.

As of 2026-04-16, the lab was deployed into FS Capabilities:

- tenant: `fscaptest.onmicrosoft.com`
- subscription: `FS Capabilities - Test External AVD`
- subscription ID: `56bf2a01-7815-4df3-a396-b9b4d6a55362`
- resource group: `externalavd-test-rg`
- VNet: `extavd-testing-centralus`
- subnet: `avd-hostpools-centralus`
- session host private IP: `10.10.0.5`
- backend private IP: `10.10.0.4`
- deployment result:
  - `23` added
  - `0` changed
  - `0` destroyed

The historical `platform-sandbox` deployment remains useful as prior lab
context, but it is no longer the active environment.

## What Is Installed And Working

- `DBTEST01` is deployed and bootstrapped.
- `DBTEST01` exposes:
  - `\\DBTEST01\RDPAPPS$`
  - `\\DBTEST01\RDPCONFIG$`
  - `\\DBTEST01\RDPDATA$`
- `RDPDISC01` can browse those three shares.
- `RDPDISC01` and `DBTEST01` both have `AADLoginForWindows` installed and
  succeeded.
- Entra VM login RBAC was previously present on both VMs for the original test
  operator in the source tenant.
- `RDPWin` is installed on `RDPDISC01`.
- `RDPWin` works from a full desktop session on `RDPDISC01`.
- The FS Capabilities rebuild completed successfully:
  - `db-test-01` exists
  - `rdp-discovery-01` exists
  - both VMs have `AADLoginForWindows` in succeeded state
  - `RDPDISC01` AVD registration extension succeeded
  - AVD workspace, host pool, and app groups were created in
    `externalavd-test-rg`

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
  - current host pool preferred app group type: `Desktop`
  - the original source-tenant test user previously had:
    - `Desktop Virtualization User` on `dag-rdp-discovery-test`
    - no entitlement on `rag-rdp-discovery-test`

This means the current Entra user experience is desktop-first again, with
desktop-session shaping on the host rather than pure RemoteApp.

## Most Important Current Limitation

Pure RemoteApp is not usable for `RDPWin`, and it is no longer the active test
path.

Current observed behavior:

- selecting the pure RemoteApp reaches Windows `Welcome`
- the user profile loads successfully
- the session logs off almost immediately afterward
- enabling the enhanced RemoteApp shell runtime did not change that outcome
- a clean retest after the Zen license was reactivated still crashed
- the current desktop model now launches `RDPWin` at logon for non-admin users

Interpretation:

- Entra login is working
- AVD brokering is working
- profile load is working
- the Zen license issue was real, but it was not the root cause of the pure
  RemoteApp crash
- the remaining work is on the desktop-shaped user experience and any residual
  backend/app validation, not on proving RemoteApp

## Working Assumption

The active model is now:

- AVD desktop session for the user path
- local policy / scripted session shaping on `RDPDISC01`
- auto-launch `RDPWin` at logon
- make the session feel app-like
- log off the session when `RDPWin` closes

This is closer to the current TERM-server behavior than Bastion, and is more
realistic than forcing pure RemoteApp if `RDPWin` is not RemoteApp-clean.

## PCI Direction

The lab is now being aligned to a PCI-ready target state.

That is not the same thing as declaring PCI DSS compliance. The active design
goal is a more defensible control model built around:

- MFA-backed Entra / AVD user access
- dedicated non-admin users for the app path
- separate admin access for maintenance
- deterministic app launch at logon
- deterministic full logoff on app close
- auditable control execution

Reference plan:

- `docs/PCI_ALIGNMENT_PLAN.md`
- `docs/ACCESS_AND_ROUTING_PLAN.md`

## Current Desktop Session Behavior

`RDPDISC01` now has host-side session shaping applied:

- non-admin users enter through the AVD desktop
- `RDPWin` auto-launches at Windows logon
- when `RDPWin` exits, Windows logs off the session
- disconnected sessions are capped to clean up quickly
- administrative users keep the normal desktop experience
- `explorer.exe` remains running because killing or replacing the shell caused
  `RDPWin` instability during testing
- `Server Manager` is suppressed at logon

Current PCI-relevant gap:

- the current `HKLM\...\Run` launcher is not reliable across all Entra / AVD
  users and should not be treated as the final compliance-grade control

Applied host-side items:

- launcher script:
  - `C:\ProgramData\RDPWinLab\Start-RDPWinDesktop.ps1`
- Run key:
  - `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run\RDPWinDesktopLauncher`
- session policy values:
  - `fResetBroken = 1`
  - `MaxDisconnectionTime = 60000`

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

Files additionally updated to support FS Capabilities landing-zone reuse:

- `terraform/main.tf`
- `terraform/variables.tf`
- `terraform/locals.tf`
- `terraform/outputs.tf`
- `terraform/modules/network/`
- `terraform/modules/workspace/`
- `inventories/group_vars/all.yml`
- `inventories/group_vars/all.example.yml`

## What Was Verified Recently

- `tofu validate` passed against the FS Capabilities target
- `tofu plan` passed against the FS Capabilities target
- `tofu apply` completed successfully in FS Capabilities
- `az` confirmed:
  - `rdp-discovery-01-aadlogin` succeeded
  - `db-test-01-aadlogin` succeeded
  - `rdp-discovery-01-avd-register-*` succeeded
  - VM login RBAC was applied for the FS Capabilities Entra operator object
- Bastion SKU is still `Developer`
- AVD control plane confirmed in FS Capabilities:
  - workspace `ws-rdp-discovery-test` exists
  - desktop group `dag-rdp-discovery-test` exists
  - RemoteApp group `rag-rdp-discovery-test` exists
  - host pool `hp-rdp-discovery-test` exists
- Event logs confirmed:
  - RDS logon/profile load succeeds for the test user
  - pure RemoteApp session exits immediately after logon
  - enhanced RemoteApp shell runtime did not fix the pure RemoteApp failure
- DB-side checks confirmed:
  - `Actian Zen Cloud Server` is running on `DBTEST01`
  - `RDPWin Monitor GDS Reservations` is running
  - the temporary Zen license was directly queried and shown as `Expired` on
    `2026-04-15`
  - the Zen license was reactivated and `Btrieve Error 161` cleared
  - RemoteApp still crashes after the license fix
- UX shaping checks confirmed:
  - shell-kill and aggressive Start/taskbar restrictions destabilized `RDPWin`
  - those restrictions were rolled back
  - no supported local GPO was found for “disable left-click Start but keep
    right-click Start”
  - `HKLM\...\Run` launcher behavior is inconsistent across users:
    `AzureAD\ChadLampton` logged launcher activity, while
    another non-admin Entra test user did not

## Next Recommended Work

Do not spend time on more infrastructure build-out first.

The next meaningful work is:

1. validate the freshly deployed FS Capabilities lab
2. confirm AVD session-host health and user-path access in the new tenant
3. keep the desktop model as the primary user path
4. treat pure RemoteApp as a tested dead end unless new vendor guidance says
   otherwise
5. replace the current `HKLM Run` launcher with a more reliable logon-time
   trigger, preferably a Scheduled Task
6. keep `explorer.exe` alive and avoid shell replacement or aggressive Start
   menu lockdown
7. define Entra security groups for per-database routing and treat them as the
   routing source of truth
8. build the local routing-broker layer on `RDPDISC01` so users are assigned to
   a single DB target at launch time
9. validate the current desktop auto-launch and full-logoff flow end to end
   with a dedicated non-admin Entra user
10. continue backend/app validation on `DBTEST01` only if a new runtime error
   appears
11. document any remaining UX compromises instead of chasing unsupported shell
   behavior

## Probe Guidance

The probe remains useful for install/config drift checks, but it is not the
current blocker. The main open work is validating the stable desktop-shaped user
path and only chasing backend state again if a new runtime error appears.

Probe path on the Windows host:

`C:\Temp\Invoke-RDPWinLabProbe.ps1`

## Related Repos

- production AVD repo:
  - `/Users/chad.lampton/Documents/repo/rdp-avd-fshosted`
- SAW reference repo:
  - `/Users/chad.lampton/Documents/repo/saw-avd-fshosted`
- discovery notes:
  - `/Users/chad.lampton/Documents/rdp-soft-discovery`
