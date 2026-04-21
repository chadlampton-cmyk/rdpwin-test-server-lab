# Runbook

Last updated: 2026-04-21.

## Purpose

This document defines the operator flow for the Azure-hosted `RDPWin` lab.

## Before You Start

Confirm:

- `az` is installed and logged in
- `tofu` is installed
- `ansible-playbook` is installed
- `inventories/group_vars/all.yml` exists
- `SESSIONHOST_ADMIN_PASSWORD` is set if not stored in `all.yml`
- `inventories/group_vars/all.yml` includes the `dbserver_*` and
  `dbserver_bootstrap_*` values if `DBTEST01` will be deployed

Quick checks:

```bash
az account show --query "{name:name,id:id,tenantId:tenantId}" -o yaml
command -v tofu
command -v ansible-playbook
ls -l inventories/group_vars/all.yml
```

## Plan

```bash
ansible-playbook playbooks/plan_lab.yml
```

Expected behavior:

- preflight validation
- deployment context summary
- generated `terraform/ansible.auto.tfvars.json`
- `tofu init`
- `tofu validate`
- `tofu plan`

## Apply

```bash
ansible-playbook playbooks/deploy_lab.yml
```

Expected behavior:

- same preflight and context summary
- `tofu init`
- `tofu validate`
- `tofu plan`
- `tofu apply`
- VM login RBAC assignments when principal IDs are configured
- AVD user assignments when AVD user principal IDs are configured
- both app groups associated to the workspace when enabled

## After Deployment

Bootstrap `DBTEST01` after the VM exists:

```bash
ansible-playbook playbooks/configure_dbserver.yml
```

Expected behavior:

- verifies Azure CLI session and target VM
- initializes the attached raw data disk
- formats it to `F:`
- copies the repo layout manifest and `New-DBTEST01Layout.ps1` onto the VM
- creates the `F:\RDPDiscovery` folder tree
- creates the hidden SMB shares when enabled

## Current Lab Status

Historical deployed state in `platform-sandbox`:

- session host VM: `rdp-discovery-01` / `RDPDISC01`
- DB backend VM: `db-test-01` / `DBTEST01`
- DB backend private IP: `10.210.10.5`
- DB backend data root: `F:\RDPDiscovery`
- `RDPDISC01` can browse `\\DBTEST01\RDPAPPS$`, `\\DBTEST01\RDPCONFIG$`, and
  `\\DBTEST01\RDPDATA$`
- both VMs have `AADLoginForWindows` in succeeded state
- VM login RBAC for the original source-tenant test operator was present on
  both VMs

Current active target and deployed state:

- tenant: `fscaptest.onmicrosoft.com`
- subscription: `FS Capabilities - Test External AVD`
- subscription ID: `56bf2a01-7815-4df3-a396-b9b4d6a55362`
- current test operator UPN:
  `chad.lampton@fullsteamtest.onmicrosoft.com`
- resource group: `externalavd-test-rg`
- VNet: `extavd-testing-centralus`
- subnet: `avd-hostpools-centralus`
- session host private IP: `10.10.0.5`
- backend private IP: `10.10.0.4`
- workspace: `RDP Discovery Test Workspace`
- app groups:
  - `RDP Discovery Test RemoteApp`
  - `RDP Discovery Test Desktop`
- session host AVD status:
  - `Available`
  - `updateState: Succeeded`
- deployment result:
  - `23` resources added
  - `0` changed
  - `0` destroyed

## Current Access Model

- admin access:
  - use Bastion/direct admin path with `localadmin`
- user test access:
  - use Windows App / AVD

Current external-tenant user guidance:

- create tenant-local test users in `fscaptest` with
  `Entra ID -> Users -> New user -> Create new user`
- the current minimum tested working Entra role for MFA registration and AVD
  sign-in is `Message Center Reader`
- `Guest Inviter` alone is not sufficient for MFA registration
- treat `Message Center Reader` as a temporary workaround under evaluation, not
  the final customer-user role model

Do not treat Bastion as the primary user-validation path. Bastion is now the
admin path only.

## Current AVD Limitation

`RDPWin` works in a full desktop session on `RDPDISC01`, but fails when exposed
as a pure RemoteApp.

Observed current behavior:

- selecting the `RDPWin` RemoteApp reaches Windows `Welcome`
- the user profile loads
- the session logs off almost immediately

Additional proof:

- the Zen temporary license on `DBTEST01` was reactivated
- pure RemoteApp still crashed afterward

This means the current blocker is app/session behavior, not AVD brokering and
not the expired Zen license.

## Current Backend Limitation

`DBTEST01` should currently be treated as a standalone Windows file server with
`AADLoginForWindows`, not as a domain-backed SMB authorization target.

Current implications:

- user-specific UNC / share authorization tied to `RDPNT1000`, `RDPNT2000`, and
  `RDPNT3000` is not currently trustworthy on the live standalone `DBTEST01`
- local groups on `DBTEST01` are placeholders, not the final access-control
  plane
- do not spend more time trying to force Entra-only SMB / NTFS ACL resolution
  on the current server state

Chosen remediation path:

- deploy `Microsoft Entra Domain Services`
- join `DBTEST01` to the managed domain
- reapply the `RDPNT1000/2000/3000` authorization model with domain-resolvable
  principals

## Current Recommended Operator Flow

1. confirm `RDPDISC01` AVD session-host status is still `Available` in FS
   Capabilities
2. confirm external-tenant MFA registration and AVD sign-in still work for the
   current test user model
3. confirm VM sign-in works in the new tenant
4. confirm raw UNC access from `RDPDISC01` to `DBTEST01` after app/config
   staging, but do not treat that as proof of final user authorization
5. use Windows App for user-path testing
6. use Bastion only for admin repair/troubleshooting
7. if testing install/config drift, run the probe from the host:
   `C:\Temp\Invoke-RDPWinLabProbe.ps1`
8. for the next implementation step, prefer a desktop session that auto-launches
   `RDPWin` over pure RemoteApp
9. do not reintroduce shell-kill or aggressive Start/taskbar lockdown changes
   unless the vendor provides a specific supported requirement
10. for PCI-aligned implementation, do not rely on the current `HKLM Run`
   launcher as the final control; replace it with a deterministic logon-time
   trigger before treating the design as ready
11. for UNC / SMB repair, begin planning `Microsoft Entra Domain Services`
    rather than more Entra-only ACL experiments on `DBTEST01`
