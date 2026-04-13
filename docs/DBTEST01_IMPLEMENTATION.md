# DBTEST01 Implementation

## Purpose

This note tracks the repo files now in place for `DBTEST01` infrastructure and
post-deploy bootstrap.

## Current Prep State

Implemented:

- design doc: `docs/DBTEST01.md`
- layout manifest: `config/dbtest01-layout.json`
- Windows folder/share builder: `scripts/New-DBTEST01Layout.ps1`
- Terraform module: `terraform/modules/dbserver/`
- root Terraform wiring for `DBTEST01`
- inventory variables for the DB VM and bootstrap settings
- VM, NIC, optional data disk, and optional `AADLoginForWindows`
- outputs exposing `DBTEST01` private IP and VM name
- post-deploy bootstrap role: `roles/dbserver_bootstrap/`
- post-deploy playbook: `playbooks/configure_dbserver.yml`

Current design choices:

- `DBTEST01` is deployed into the same resource group, location, VNet, and
  subnet as the discovery session host
- the backend data root is `F:\RDPDiscovery`
- `F:` is used intentionally because Azure Windows VMs commonly reserve `D:` for
  the temporary disk
- bootstrap runs from `localhost` through Azure CLI and `az vm run-command
  invoke` instead of introducing WinRM

## Next Code Files To Touch

- `inventories/group_vars/all.yml`
- `playbooks/plan_lab.yml`
- `playbooks/deploy_lab.yml`
- `playbooks/configure_dbserver.yml`

Current operator sequence:

1. populate `dbserver_*` values in `inventories/group_vars/all.yml`
2. run `ansible-playbook playbooks/plan_lab.yml`
3. run `ansible-playbook playbooks/deploy_lab.yml`
4. run `ansible-playbook playbooks/configure_dbserver.yml`
