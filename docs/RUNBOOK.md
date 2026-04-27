# Runbook

Last updated: 2026-04-27.

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
- `RDPDISC01` could browse the older hidden-share layout on `DBTEST01`
- both VMs originally had `AADLoginForWindows` in succeeded state
- VM login RBAC for the original source-tenant test operator was present on
  both VMs

Current active target and deployed state:

- tenant: `fullsteamhostedtest.onmicrosoft.com`
- tenant ID: `2fc43150-f428-43e0-8eac-0a547eaa5dc6`
- subscription: `FS Capabilities - Test External AVD`
- subscription ID: `56bf2a01-7815-4df3-a396-b9b4d6a55362`
- current test operator UPN:
  `chad.lampton@fullsteamhosted.com`
- resource group: `externalavd-test-rg`
- VNet: `extavd-testing-centralus`
- subnet: `avd-hostpools-centralus`
- AAD DS subnet: `aadds-centralus`
- AAD DS subnet prefix: `10.10.10.0/24`
- planned AAD DS managed domain name: `fshostedtest.onmicrosoft.com`
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
- post-move user-facing RBAC had to be recreated in the new workforce tenant
- current staged tenant users:
  - `CSS0@fullsteamhostedtest.onmicrosoft.com`
  - `HSC1@fullsteamhostedtest.onmicrosoft.com`
  - `TCS2@fullsteamhostedtest.onmicrosoft.com`
- current staged Entra cloud groups:
  - `RDPNT1000`
  - `RDPNT2000`
  - `RDPNT3000`

## Current Access Model

- admin access:
  - use Bastion/direct admin path with `localadmin`
- user test access:
  - use Windows App / AVD

Current workforce-tenant user guidance:

- use tenant-local named users in `fullsteamhostedtest.onmicrosoft.com`
- current staged users are:
  - `CSS0@fullsteamhostedtest.onmicrosoft.com`
  - `HSC1@fullsteamhostedtest.onmicrosoft.com`
  - `TCS2@fullsteamhostedtest.onmicrosoft.com`
- current staged group mapping is:
  - `CSS0 -> RDPNT1000`
  - `HSC1 -> RDPNT2000`
  - `TCS2 -> RDPNT3000`
- app-group RBAC is assigned to the groups with `Desktop Virtualization User`
- VM sign-in RBAC is assigned to the groups with `Virtual Machine User Login`

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

The original hybrid experiment of an Entra-joined `RDPDISC01` plus an
AAD DS-joined `DBTEST01` was proven to be incomplete for seamless `RDPWin`
backend access.

Current live findings:

- `DBTEST01` resolves domain principals such as `FSHOSTEDTEST\\RDPNT1000`
- the active staged share trees are:
  - `\\DBTEST01\RDPNT1000`
  - `\\DBTEST01\RDPNT2000`
  - `\\DBTEST01\RDPNT3000`
- the `RDPNT1000` share grants:
  - `FSHOSTEDTEST\\RDPNT1000 : Full`
  - `DBTEST01\\RDPNT1000 : Full`
- NTFS on `F:\\RDPNT1000` and `F:\\RDPNT1000\\RDP` grants
  `FSHOSTEDTEST\\RDPNT1000`
- the live backend data folder for `CSS0` is `F:\\RDPNT1000\\RDP\\RDP01`
- manual authentication from the `CSS0` session using
  `fshostedtest\\CSS0` succeeded against `\\DBTEST01\\RDPNT1000`
- after the DNS change to the AAD DS controllers, `RDPDISC01` could locate the
  managed-domain DCs successfully

Why the original hybrid host model failed:

- the session host `RDPDISC01` was still Microsoft Entra joined
- the file server `DBTEST01` was Microsoft Entra Domain Services joined
- `klist cloud_debug` in the live `CSS0` session showed:
  - `Cloud Kerberos enabled by policy: 0`
  - no Cloud Referral TGT
  - no cached tickets for seamless SMB access
- Windows Security prompted for credentials when `CSS0` tried to reach
  `\\DBTEST01\\RDPNT1000`
- this proved the remaining problem was SMB authentication / SSO flow, not
  missing shares, not missing folders, and not missing ACLs

Current chosen architecture:

- keep Entra ID at the edge for Windows App / AVD sign-in
- put both Windows servers on the AAD DS backend auth model
- use AAD DS for `RDPWin`, SMB shares, and database access
- do not treat the Entra-joined `RDPDISC01` plus AAD DS-joined `DBTEST01` model
  as the final production-like design for this app

Current confirmed outcome:

- the final working model keeps Entra at the edge and AAD DS on both Windows
  servers for backend auth
- `CSS0` proved the architecture, but `HSC1` then exposed incomplete
  permissions on `RDPNT2000`
- share and NTFS permissions on `DBTEST01` were corrected across all
  `RDPNT1000/2000/3000` trees
- `RDPWin` now resolves and opens the correct backend database per staged user
- current state:
  - `Microsoft Entra Domain Services` resource exists
  - managed domain: `fshostedtest.onmicrosoft.com`
  - latest Azure verification on `2026-04-24` showed
    `provisioningState: Succeeded`

Current `RDPDISC01` join-repair status:

- `IMDS` now reports the new tenant:
  - `2fc43150-f428-43e0-8eac-0a547eaa5dc6`
- stale old-tenant values were removed from:
  - `HKLM\\SOFTWARE\\Microsoft\\RDInfraAgent`
- `HKLM\\SOFTWARE\\Microsoft\\RDInfraAgent\\SxsStack`
- `HKLM\\SYSTEM\\CurrentControlSet\\Control\\CloudDomainJoin`
- the first `AADLoginForWindows` uninstall became stuck in `Deleting`
- rebuild/recovery that cleared the block:
  - delete the VM resource only
  - preserve and reattach the existing OS disk
  - preserve and reattach the existing NIC
  - recreate the VM
  - reinstall `AADLoginForWindows`
- note:
  - the above `dsregcmd` output was the intermediate recovered state before the
    lab moved `RDPDISC01` onto the managed-domain backend model
- current VM/extension state:
  - guest agent: `Ready`
  - `AADLoginForWindows: Succeeded`
- access fix applied after rebuild:
  - `RDPNT1000` was granted `Virtual Machine User Login` on
    `rdp-discovery-01`
- current validation result:
  - Windows App sign-in succeeded with
    `CSS0@fullsteamhostedtest.onmicrosoft.com`

## Current Recommended Operator Flow

1. confirm the staged user groups still have both:
   - `Desktop Virtualization User` on the desktop app group
   - `Virtual Machine User Login` on `rdp-discovery-01`
2. use Windows App for workforce-user testing
3. confirm both Windows servers remain on the AAD DS-backed backend auth model
   before spending time on app-level debugging
4. if a user cannot reach the correct backend path, validate the matching
   `RDPNT1000/2000/3000` share and NTFS ACLs on `DBTEST01`
5. treat raw UNC access from `RDPDISC01` as a useful check, but compare the
   user's effective `RDPNT` permissions before changing routing files
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
11. keep the `RDPNT` share trees aligned:
    - `CSS0 -> RDPNT1000`
    - `HSC1 -> RDPNT2000`
    - `TCS2 -> RDPNT3000`
    because ACL drift on those folders was the last live blocker after the
    identity model was corrected
