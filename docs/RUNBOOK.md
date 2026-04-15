# Runbook

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

Current deployed state in `platform-sandbox`:

- session host VM: `rdp-discovery-01` / `RDPDISC01`
- DB backend VM: `db-test-01` / `DBTEST01`
- DB backend private IP: `10.210.10.5`
- DB backend data root: `F:\RDPDiscovery`
- `RDPDISC01` can browse `\\DBTEST01\RDPAPPS$`, `\\DBTEST01\RDPCONFIG$`, and
  `\\DBTEST01\RDPDATA$`
- both VMs have `AADLoginForWindows` in succeeded state
- VM login RBAC for `chad.lampton@fullsteamhosted.com` is present on both VMs
- workspace: `RDP Discovery Test Workspace`
- app groups:
  - `RDP Discovery Test RemoteApp`
  - `RDP Discovery Test Desktop`
- session host AVD status:
  - `Available`
  - `updateState: Succeeded`

## Current Access Model

- admin access:
  - use Bastion/direct admin path with `localadmin`
- user test access:
  - use Windows App / AVD

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

## Current Recommended Operator Flow

1. confirm `RDPDISC01` AVD session-host status is still `Available`
2. confirm UNC access from `RDPDISC01` to `DBTEST01`
3. use Windows App for user-path testing
4. use Bastion only for admin repair/troubleshooting
5. if testing install/config drift, run the probe from the host:
   `C:\Temp\Invoke-RDPWinLabProbe.ps1`
6. for the next implementation step, prefer a desktop session that auto-launches
   `RDPWin` over pure RemoteApp
7. do not reintroduce shell-kill or aggressive Start/taskbar lockdown changes
   unless the vendor provides a specific supported requirement
