# RDPWin Test Server Lab

## Purpose

This repo is for building a temporary Windows test server that is close enough to the current Resort Data Processing terminal-server pattern to test `RDPWin`.

This is not the final Azure Virtual Desktop design. This is not the production `rdp-avd-fshosted` infrastructure repo.

## Test Goal

Create a controlled host where the team can install the authoritative `RDPWin` package, apply the minimum required configuration, launch `RDPWin.exe`, and validate connectivity, login, routing, printing, user state, and close/logoff behavior before production AVD session-host automation is finalized.

## Current Lab Stance

First prove a fresh `RDPWin` / session-host build. Do not begin by cloning a TERM server or by rebuilding `DB01` / `DB02`.

Do not treat this repo as permission to test against retained production dependencies. Use the approved non-production test user, test database, and share/path mapping for discovery.

## Current Reference Model

Discovery currently says:

- customers use a single app-like RDS session
- support users have a separate full-desktop workflow
- `RDPWin.exe` currently launches from `C:\ProgramData\ResortDataProcessing\RDPWin\RDPWin5Client\RDPWin.exe`
- legacy terminal servers are split across `DB01` and `DB02`
- `TERM01` / `TERM03` align to `DB01`
- `TERM02` / `TERM04` / likely `TERM06` align to `DB02`
- universal print drivers are the current print assumption
- broad per-user `RDPWin` state has not been confirmed

## Non-Goals

- do not design the final AVD production platform here
- do not migrate `DB01`, `DB02`, IRM/web, AD, backup, or payment systems here
- do not clone an existing `TERM` server as the long-term golden image
- do not store customer data, installer secrets, passwords, certificates, or vendor credentials in git

## Things To Prove

1. Which `RDPWin` MSI/package and version should be the clean baseline?
2. What install command works on a fresh Windows host?
3. What post-install files, registry values, ODBC/Actian/client config, shares, or shortcuts are required?
4. What determines `DB01` versus `DB02` routing?
5. Can the app run from a fresh, non-cloned host?
6. Does the app need AD/domain join, Kerberos/NTLM, UNC shares, mapped drives, or machine trust?
7. Does a normal test user create required profile state?
8. Does printing work with the intended redirection/driver model?

## Lab Probe

This repo includes a Windows-side probe:

- `scripts/Invoke-RDPWinLabProbe.ps1`

Use it on the test server before install, after Actian install, after `RDPWin` install, after config, and around a manual launch smoke test.

Example:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\scripts\Invoke-RDPWinLabProbe.ps1 -Phase Baseline -TargetHosts DBTEST01 -SharePaths '\\DBTEST01\RDPAPPS$','\\DBTEST01\RDPCONFIG$','\\DBTEST01\RDPDATA$'
```

See:

- `docs/TEST_PLAN.md`
- `scripts/README.md`

## Azure Lab Automation

This repo now also contains a narrow SAW-style Azure automation structure for a greenfield RDPWin lab:

- `inventories/`
- `playbooks/`
- `roles/lab_tofu/`
- `terraform/`
- `docs/RUNBOOK.md`
- `docs/ARCHITECTURE.md`
- `docs/VALIDATION.md`

This automation now builds the Azure lab platform:

- one resource group
- one VNet/subnet
- one pooled AVD host pool
- one RemoteApp application group with an `RDPWin` app entry
- one workspace
- one Windows Server 2022 discovery session host
- one Windows Server 2022 `DBTEST01` backend server
- `AADLoginForWindows` on both Windows VMs so the lab is prepared for Entra VM sign-in
- optional Entra RBAC assignments on both VMs for VM user/admin login

Current discovery-test naming in the example inventory:

- `rg-rdp-discovery-test`
- `vnet-rdp-discovery-test`
- `snet-rdp-discovery-sessionhosts`
- `hp-rdp-discovery-test`
- `rag-rdp-discovery-test`
- `ws-rdp-discovery-test`
- `rdp-discovery-01`
- Windows computer name: `RDPDISC01`
- `db-test-01`
- Windows computer name: `DBTEST01`

It does not install `RDPWin` or Actian. That remains a lab test step after the VM exists.

Repo planning now also includes a `DBTEST01` backend server design for a
temporary Azure-hosted database and file server used by discovery. The current
design material lives in:

- `docs/DBTEST01.md`
- `config/dbtest01-layout.json`
- `scripts/New-DBTEST01Layout.ps1`

The repo also now includes a post-deploy bootstrap path for `DBTEST01` so the
data disk, folder layout, and SMB shares can be initialized from the same
Ansible-driven operator flow:

- `playbooks/configure_dbserver.yml`
- `roles/dbserver_bootstrap/`

Current operator access path for the deployed lab host is Bastion admin access. RemoteApp publishing exists for the AVD control plane, but Windows-side discovery work should assume Bastion for host administration.

## Current Deployed State

As of 2026-04-13, the Azure lab has been deployed in `platform-sandbox` and includes:

- `rdp-discovery-01` / `RDPDISC01`
- `db-test-01` / `DBTEST01`

`RDPDISC01` is currently:

- deployed in `rg-rdp-discovery-test`
- on the same VNet/subnet as `DBTEST01`
- provisioned with the `AADLoginForWindows` extension
- registered to the AVD host pool

`DBTEST01` is currently:

- deployed in `rg-rdp-discovery-test`
- on the same VNet/subnet as the discovery server
- running with private IP `10.210.10.5`
- provisioned with a system-assigned managed identity
- provisioned with the `AADLoginForWindows` extension
- bootstrapped with `F:\RDPDiscovery`

Current validated operator findings:

- `RDPDISC01` can reach `\\DBTEST01\RDPAPPS$`
- `RDPDISC01` can reach `\\DBTEST01\RDPCONFIG$`
- `RDPDISC01` can reach `\\DBTEST01\RDPDATA$`
- Entra VM login RBAC has been applied for `chad.lampton@fullsteamhosted.com` on both VMs
- the current Bastion in `rg-rdp-discovery-test` is `Developer` SKU, so terminal/native-client tunnel workflows should not be treated as available in this lab without a paid SKU change

Current known installer staging outside git:

- `/Users/chad.lampton/Documents/RDPInstalls/TermServers/RDPWinMSI_5.6.001.6.msi`
- `/Users/chad.lampton/Documents/RDPInstalls/TermServers/Zen_Patch_Client-16.11.006.000.exe`
- `/Users/chad.lampton/Documents/RDPInstalls/TermServers/CRRuntime_64bit_13_0_39.msi`
- `/Users/chad.lampton/Documents/RDPInstalls/TermServers/VC_redist.x64.exe`
- `/Users/chad.lampton/Documents/RDPInstalls/TermServers/VC_redist.x86.exe`

The next work is Windows-side validation and application discovery, not more
base infrastructure build-out. The first identity automation step, placing both
test servers into the Entra VM sign-in path, is already part of the deploy.

## Quickstart

```bash
cp inventories/group_vars/all.example.yml inventories/group_vars/all.yml
export SESSIONHOST_ADMIN_PASSWORD='StrongPasswordHere'
ansible-playbook playbooks/plan_lab.yml
```

Optional Entra VM login RBAC example:

```yaml
vm_user_login_principals:
  - "user@example.com"
vm_admin_login_principals:
  - "RDP Discovery Admins"
```

If you already have raw object IDs, those still work:

```yaml
vm_user_login_principal_ids:
  - "11111111-1111-1111-1111-111111111111"
vm_admin_login_principal_ids:
  - "22222222-2222-2222-2222-222222222222"
```

Bootstrap `DBTEST01` after deploy:

```bash
ansible-playbook playbooks/configure_dbserver.yml
```

## Lint And Validation

This repo includes SAW-style lint and validation guardrails:

- `.ansible-lint`
- `.yamllint`
- `.pre-commit-config.yaml`
- `terraform/.tflint.hcl`
- `.github/workflows/lint.yml`
- `.github/workflows/terraform-checks.yml`
- `.github/workflows/tfsec.yml`

Useful local commands:

```bash
ansible-playbook --syntax-check playbooks/plan_lab.yml
ansible-playbook --syntax-check playbooks/deploy_lab.yml
.venv/bin/ansible-lint
.venv/bin/yamllint inventories playbooks roles .github .ansible-lint .yamllint
tofu -chdir=terraform fmt -check -recursive
tofu -chdir=terraform init -backend=false
tofu -chdir=terraform validate
./.tools/bin/tflint --init --chdir terraform
./.tools/bin/tflint --recursive --chdir terraform
```

Repo-local tool paths:

- Python linters install into `.venv/`
- `tflint` installs into `.tools/bin/`
- `yamllint` should target repo YAML paths, not the whole repo root after `.venv/` exists

## Related Repos And Discovery

- `/Users/chad.lampton/Documents/repo/rdp-avd-fshosted`
- `/Users/chad.lampton/Documents/rdp-soft-discovery`
