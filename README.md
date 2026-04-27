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

Copy `scripts/Invoke-RDPWinLabProbe.ps1` to `C:\Temp\Invoke-RDPWinLabProbe.ps1`
on the Windows host, then run:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File C:\Temp\Invoke-RDPWinLabProbe.ps1 -Phase Baseline -TargetHosts DBTEST01 -SharePaths '\\DBTEST01\RDPNT1000','\\DBTEST01\RDPNT2000','\\DBTEST01\RDPNT3000'
```

See:

- `docs/TOMORROW_TEST_CHECKLIST.md`
- `docs/TEST_PLAN.md`
- `docs/CURRENT_STATE.md`
- `scripts/README.md`

## Azure Lab Automation

This repo now also contains a narrow SAW-style Azure automation structure for a greenfield RDPWin lab:

- `inventories/`
- `playbooks/`
- `roles/lab_tofu/`
- `terraform/`
- `docs/RUNBOOK.md`
- `docs/ARCHITECTURE.md`
- `docs/CURRENT_STATE.md`
- `docs/VALIDATION.md`

This automation now builds the Azure lab platform:

- one resource group
- one VNet/subnet
- one pooled AVD host pool
- one RemoteApp application group with an `RDPWin` app entry
- one desktop application group for desktop-session testing
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

Current operator access model is split:

- Bastion/direct admin path for maintenance with `localadmin`
- Windows App / AVD path for end-user-style testing

## Current Deployed State

Historical deployment state:

As of 2026-04-15, the Azure lab was deployed in `platform-sandbox` and included:

- `rdp-discovery-01` / `RDPDISC01`
- `db-test-01` / `DBTEST01`

`RDPDISC01` is currently:

- deployed in `rg-rdp-discovery-test`
- on the same VNet/subnet as `DBTEST01`
- provisioned with the `AADLoginForWindows` extension
- registered to the AVD host pool
- repaired to support AVD session-host health by installing the missing
  `Remote Desktop Session Host` role

`DBTEST01` is currently:

- deployed in `rg-rdp-discovery-test`
- on the same VNet/subnet as the discovery server
- running with private IP `10.210.10.5`
- provisioned with a system-assigned managed identity
- provisioned with the `AADLoginForWindows` extension
- bootstrapped with `F:\RDPDiscovery`

Historical validated operator findings:

- `RDPDISC01` can reach `\\DBTEST01\RDPAPPS$`
- `RDPDISC01` can reach `\\DBTEST01\RDPCONFIG$`
- `RDPDISC01` can reach `\\DBTEST01\RDPDATA$`
- Entra VM login RBAC was applied for the original test operator on both VMs
- AVD workspace now exposes both:
  - `RDP Discovery Test RemoteApp`
  - `RDP Discovery Test Desktop`
- `RDPDISC01` AVD session-host status is now `Available`
- pure `RDPWin` RemoteApp launch currently fails after logon, while full desktop
  launch works
- the active user path is now the desktop app group, not the RemoteApp group
- desktop-session shaping has been applied on `RDPDISC01` so non-admin users
  auto-launch `RDPWin` and log off when it closes
- the temporary Zen license on `DBTEST01` was confirmed expired on
  `2026-04-15`, then reactivated
- `Btrieve Error 161` cleared after the Zen license was reactivated
- a post-license retest proved pure RemoteApp still crashes, so the license was
  not the root cause of the RemoteApp failure
- current DB-side findings still worth tracking include:
  - `Actian Zen Cloud Server` running
  - `RDPWin Monitor GDS Reservations` running
  - `RDPWin Monitor` and `RDPWin Monitor GDS` installed but not the primary
    user-path blocker
- aggressive Start/taskbar shell restrictions were tested and rolled back
  because they destabilized `RDPWin`
- the current stable host-side shaping keeps `explorer.exe` alive, suppresses
  `Server Manager`, auto-launches `RDPWin`, and logs off when `RDPWin` closes
- the current Bastion in `rg-rdp-discovery-test` is `Developer` SKU and should
  be treated as the admin path, not the primary user-path test model

Current known installer staging outside git:

- `/Users/chad.lampton/Documents/RDPInstalls/TermServers/RDPWinMSI_5.6.001.6.msi`
- `/Users/chad.lampton/Documents/RDPInstalls/TermServers/Zen_Patch_Client-16.11.006.000.exe`
- `/Users/chad.lampton/Documents/RDPInstalls/TermServers/CRRuntime_64bit_13_0_39.msi`
- `/Users/chad.lampton/Documents/RDPInstalls/TermServers/VC_redist.x64.exe`
- `/Users/chad.lampton/Documents/RDPInstalls/TermServers/VC_redist.x86.exe`

That historical environment is no longer the active deployment target.

Active deployment state:

As of 2026-04-23, the Azure lab is running in the FS Capabilities test
subscription under the `fullsteamhostedtest.onmicrosoft.com` workforce tenant
and includes:

- resource group: `externalavd-test-rg`
- session host VM: `rdp-discovery-01` / `RDPDISC01`
- session host private IP: `10.10.0.5`
- backend VM: `db-test-01` / `DBTEST01`
- backend private IP: `10.10.0.4`
- VNet: `extavd-testing-centralus`
- subnet: `avd-hostpools-centralus`
- host pool: `hp-rdp-discovery-test`
- workspace: `ws-rdp-discovery-test`
- RemoteApp group: `rag-rdp-discovery-test`
- desktop group: `dag-rdp-discovery-test`
- tenant: `fullsteamhostedtest.onmicrosoft.com`
- tenant ID: `2fc43150-f428-43e0-8eac-0a547eaa5dc6`
- subscription ID: `56bf2a01-7815-4df3-a396-b9b4d6a55362`

Deployment result:

- `23` resources added
- `0` changed
- `0` destroyed
- `AADLoginForWindows` succeeded on both VMs after the initial FS
  Capabilities rebuild
- AVD registration extension succeeded on `RDPDISC01`
- the subscription move preserved the VM and AVD objects
- user-facing AVD RBAC had to be recreated in the new tenant

Current staged users and groups in `fullsteamhostedtest`:

- users:
  - `CSS0@fullsteamhostedtest.onmicrosoft.com`
  - `HSC1@fullsteamhostedtest.onmicrosoft.com`
  - `TCS2@fullsteamhostedtest.onmicrosoft.com`
- Entra cloud groups:
  - `RDPNT1000`
  - `RDPNT2000`
  - `RDPNT3000`
- mapping:
  - `CSS0 -> RDPNT1000`
  - `HSC1 -> RDPNT2000`
  - `TCS2 -> RDPNT3000`

The next work is validating and refining the desktop-session model, not more
base infrastructure build-out and not more pure RemoteApp troubleshooting. The
AVD desktop session that auto-launches `RDPWin` is now the active test model in
the FS Capabilities tenant.

Current recovery and identity state:

- the stale old-tenant local join state was removed from `RDPDISC01`
- the first `AADLoginForWindows` delete became stuck in Azure control-plane
  state after the local cleanup
- `rdp-discovery-01` was rebuilt from the preserved OS disk and existing NIC
- `AADLoginForWindows` was reinstalled successfully on the rebuilt VM
- Windows App sign-in was revalidated successfully with
  `CSS0@fullsteamhostedtest.onmicrosoft.com`
- the attempted hybrid model was proven incomplete:
  - `RDPDISC01` could reach `DBTEST01` only with explicit
    `fshostedtest\\CSS0` SMB auth while it remained Entra joined
  - `Cloud Kerberos enabled by policy: 0` was observed in the live `CSS0`
    session
  - VNet DNS was switched to the AAD DS controllers `10.10.10.5` and
    `10.10.10.4`
- the lab then moved to the final working backend model:
  - Windows App / AVD remains the Entra edge sign-in path
  - both Windows servers use the AAD DS backend auth model
  - `DBTEST01` share and NTFS ACLs were normalized across the
    `RDPNT1000/2000/3000` trees
  - `RDPWin` now resolves and opens the correct backend database per staged
    user instead of only working for `CSS0`

## Current Target Direction

This repo is now tracking the active workforce tenant and subscription:

- tenant: `fullsteamhostedtest.onmicrosoft.com`
- tenant ID: `2fc43150-f428-43e0-8eac-0a547eaa5dc6`
- subscription: `FS Capabilities - Test External AVD`
- subscription ID: `56bf2a01-7815-4df3-a396-b9b4d6a55362`
- primary test operator UPN:
  `chad.lampton@fullsteamhosted.com`

This means the repo now has two distinct states:

- historical state: the already-built lab in `platform-sandbox`
- active live lab: the FS Capabilities test subscription after the tenant move
  into `fullsteamhostedtest`

Do not assume the historical deployment facts above describe the current target
tenant. Use the inventory files and plan/apply path for the active target.

## PCI Direction

This lab is now being steered toward a PCI-aligned target design.

That does not mean this repo or lab is claiming PCI DSS compliance. It means
the active design decisions should support:

- Entra MFA-backed remote access through AVD / Windows App
- dedicated non-admin user access for the customer-style path
- strict separation between admin troubleshooting and user access
- deterministic app launch and full logoff behavior
- auditable control execution

The current gap is that the machine `Run`-key launcher is not reliable across
all Entra/AVD users. The next implementation step should therefore replace the
current launcher trigger with a more reliable logon-time mechanism, such as a
Scheduled Task.

There is now a confirmed backend identity architecture for the lab:

- use Entra ID at the edge for Windows App / AVD sign-in
- use Microsoft Entra Domain Services for backend Windows auth
- keep both Windows servers on the same managed-domain auth model for
  `RDPWin`, SMB, and database access
- do not treat an Entra-joined `RDPDISC01` plus AAD DS-joined `DBTEST01` as the
  final working design for this app path
- keep the `RDPNT1000/2000/3000` share and NTFS permissions aligned with the
  per-user routing model, because incomplete ACLs on `DBTEST01` were the last
  blocker after the identity model was corrected

See:

- `docs/PCI_ALIGNMENT_PLAN.md`
- `docs/HANDOFF.md`

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
