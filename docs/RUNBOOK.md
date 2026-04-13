# Runbook

## Purpose

This document defines the operator flow for the Azure-hosted RDPWin lab.

## Before You Start

Confirm:

- `az` is installed and logged in
- `tofu` is installed
- `ansible-playbook` is installed
- `inventories/group_vars/all.yml` exists
- `SESSIONHOST_ADMIN_PASSWORD` is set if not stored in `all.yml`
- `inventories/group_vars/all.yml` includes the `dbserver_*` and
  `dbserver_bootstrap_*` values if `DBTEST01` will be deployed
- `vm_user_login_principals` / `vm_admin_login_principals` or raw
  `vm_user_login_principal_ids` / `vm_admin_login_principal_ids` are set when
  Entra VM login RBAC should be created automatically

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
- Entra VM login role assignments when principal IDs are configured
- create both Windows VMs with `AADLoginForWindows` enabled when configured

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

Then use the Windows-side probe on the session host after you can reach it through Bastion:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\scripts\Invoke-RDPWinLabProbe.ps1 -Phase Baseline -TargetHosts DBTEST01 -SharePaths '\\DBTEST01\RDPAPPS$','\\DBTEST01\RDPCONFIG$','\\DBTEST01\RDPDATA$'
```

Then continue with Actian install, RDPWin install, config, and launch smoke testing.

## Current Lab Status

Current deployed state in `platform-sandbox`:

- session host VM: `rdp-discovery-01` / `RDPDISC01`
- session host `AADLoginForWindows` extension: enabled by Terraform for Entra VM sign-in
- DB backend VM: `db-test-01` / `DBTEST01`
- DB backend private IP: `10.210.10.5`
- DB backend data root: `F:\RDPDiscovery`
- DB backend power state: running
- DB backend `AADLoginForWindows` extension: succeeded
- `RDPDISC01` can browse `\\DBTEST01\RDPAPPS$`, `\\DBTEST01\RDPCONFIG$`, and `\\DBTEST01\RDPDATA$`
- Entra VM login RBAC for `chad.lampton@fullsteamhosted.com` is present on both VMs
- lab Bastion is currently `Developer` SKU, so native-client/tunnel workflows should not be assumed available

Current recommended operator flow:

1. confirm Entra sign-in RBAC on both VMs
2. verify UNC access from `RDPDISC01` to `\\DBTEST01\RDPAPPS$`, `\\DBTEST01\RDPCONFIG$`, and `\\DBTEST01\RDPDATA$`
3. run the `Baseline` probe on `RDPDISC01` against `DBTEST01` with explicit `-SharePaths`
4. install the terminal-side prerequisites from `/Users/chad.lampton/Documents/RDPInstalls/TermServers/`
5. rerun probe as `AfterActian`
6. install `RDPWinMSI_5.6.001.6.msi`
7. rerun probe as `AfterRDPWinInstall`
