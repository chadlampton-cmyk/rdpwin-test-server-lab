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

## Current State

`DBTEST01` is no longer a planned component. It is deployed and in active use in
the lab.

Current verified state:

- VM name: `db-test-01`
- Windows name: `DBTEST01`
- private IP: `10.210.10.5`
- data root: `F:\RDPDiscovery`
- hidden shares:
  - `RDPAPPS$`
  - `RDPCONFIG$`
  - `RDPDATA$`
- `RDPDISC01` can reach those shares

## Current Operator Sequence

1. populate `dbserver_*` values in `inventories/group_vars/all.yml`
2. run `ansible-playbook playbooks/plan_lab.yml`
3. run `ansible-playbook playbooks/deploy_lab.yml`
4. run `ansible-playbook playbooks/configure_dbserver.yml`
5. validate share reachability from `RDPDISC01`

## What Is Not Solved Here

- final non-production Actian Zen data set source
- exact logo names or test databases to host
- final app-side routing behavior if classic AD group selection must be
  reproduced
