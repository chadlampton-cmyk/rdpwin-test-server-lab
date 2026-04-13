# Handoff

Last updated: 2026-04-13.

## Cold-Start Instruction

Read this file first after reboot. This repo is brand new and is not the production AVD infrastructure repo.

The next Codex session should stay in:

`/Users/chad.lampton/Documents/repo/rdpwin-test-server-lab`

## Current State

- Repo created as a separate workspace for a temporary `RDPWin` test server.
- Intended location: `/Users/chad.lampton/Documents/repo/rdpwin-test-server-lab`
- This repo is specifically for test-host build notes and automation.
- Production AVD infrastructure work remains in `/Users/chad.lampton/Documents/repo/rdp-avd-fshosted`.
- Repo is an active local workspace for discovery automation, notes, and probe iteration.
- Lab plan and probe now exist:
  - `docs/TEST_PLAN.md`
  - `scripts/README.md`
  - `scripts/Invoke-RDPWinLabProbe.ps1`
- Azure automation scaffold now exists:
  - `ansible.cfg`
  - `inventories/`
  - `playbooks/`
  - `roles/lab_tofu/`
  - `terraform/`
  - `docs/RUNBOOK.md`
  - `docs/ARCHITECTURE.md`
  - `docs/VALIDATION.md`
- DB test-server design material now exists:
  - `docs/DBTEST01.md`
  - `config/dbtest01-layout.json`
  - `scripts/New-DBTEST01Layout.ps1`
- DB test-server bootstrap automation now exists:
  - `playbooks/configure_dbserver.yml`
  - `roles/dbserver_bootstrap/`
- SAW-style repo hygiene now exists:
  - `.ansible-lint`
  - `.yamllint`
  - `.pre-commit-config.yaml`
  - `.github/workflows/`
  - `terraform/.tflint.hcl`
- Repo-local lint helpers were also staged for local verification:
  - `.venv/` for Python-based linters
  - `.tools/bin/tflint` for Terraform linting

## What Was Verified

The following checks were run locally and passed:

- `ansible-playbook --syntax-check playbooks/plan_lab.yml`
- `ansible-playbook --syntax-check playbooks/deploy_lab.yml`
- `.venv/bin/ansible-lint`
- `.venv/bin/yamllint inventories playbooks roles .github .ansible-lint .yamllint`
- `tofu -chdir=terraform fmt -check -recursive`
- `tofu -chdir=terraform validate`
- `./.tools/bin/tflint --recursive --chdir terraform`

This means the repo is no longer just scaffolded. The local automation and lint
path were exercised and cleaned up to a passing state.

The following local validation checks were rerun after the `DBTEST01`
implementation and bootstrap work and also passed:

- `ansible-playbook --syntax-check playbooks/configure_dbserver.yml`
- `tofu -chdir=terraform fmt -check -recursive`
- `tofu -chdir=terraform init -backend=false`
- `tofu -chdir=terraform validate`
- `./.tools/bin/tflint --init --chdir terraform`
- `./.tools/bin/tflint --recursive --chdir terraform`

The following Azure deployment checks were also completed in `platform-sandbox`:

- `ansible-playbook playbooks/plan_lab.yml`
- `ansible-playbook playbooks/deploy_lab.yml`
- resource group created: `rg-rdp-discovery-test`
- VNet created: `vnet-rdp-discovery-test`
- subnet created: `snet-rdp-discovery-sessionhosts`
- host pool created: `hp-rdp-discovery-test`
- app group created: `rag-rdp-discovery-test`
- workspace created: `ws-rdp-discovery-test`
- session host VM created: `rdp-discovery-01`
- Windows computer name set explicitly to `RDPDISC01` to avoid the 15-character hostname limit
- DB server VM created: `db-test-01`
- Windows computer name set explicitly to `DBTEST01`
- DB server private IP confirmed: `10.210.10.5`
- DB server power state confirmed: `VM running`
- DB server managed identity confirmed: `SystemAssigned`
- DB server `AADLoginForWindows` extension confirmed in succeeded state
- `playbooks/configure_dbserver.yml` completed successfully
- DB server data disk initialized and formatted to `F:`
- DB server layout root created: `F:\RDPDiscovery`
- DB server bootstrap manifest executed successfully

AVD session-host registration has now been confirmed from inside the VM:

- `HKLM:\SOFTWARE\Microsoft\RDInfraAgent` shows `IsRegistered : 1`
- `HostPoolId` is populated
- `AgentState : 11`
- `RdAgent` service is running
- `RDAgentBootLoader` service is running

The following identity and backend-access checks were also completed in the lab:

- Entra VM login RBAC was applied for `chad.lampton@fullsteamhosted.com` on `rdp-discovery-01`
- Entra VM login RBAC was applied for `chad.lampton@fullsteamhosted.com` on `db-test-01`
- `RDPDISC01` successfully reached:
  - `\\DBTEST01\RDPAPPS$`
  - `\\DBTEST01\RDPCONFIG$`
  - `\\DBTEST01\RDPDATA$`

The following operator constraint also matters:

- the lab Bastion in `rg-rdp-discovery-test` is `Developer` SKU
- do not assume terminal/native-client tunnel workflows are available from macOS
- treat Azure portal/Bastion admin access as the current supported path unless the Bastion SKU is intentionally changed later

The following installer media is now staged locally outside git:

- `/Users/chad.lampton/Documents/RDPInstalls/TermServers/RDPWinMSI_5.6.001.6.msi`
- `/Users/chad.lampton/Documents/RDPInstalls/TermServers/Zen_Patch_Client-16.11.006.000.exe`
- `/Users/chad.lampton/Documents/RDPInstalls/TermServers/CRRuntime_64bit_13_0_39.msi`
- `/Users/chad.lampton/Documents/RDPInstalls/TermServers/VC_redist.x64.exe`
- `/Users/chad.lampton/Documents/RDPInstalls/TermServers/VC_redist.x86.exe`
- `/Users/chad.lampton/Documents/RDPInstalls/DBServers/Zen-CloudServer-16.10.004.000-win.exe`
- `/Users/chad.lampton/Documents/RDPInstalls/DBServers/Zen_Patch_CloudServer-16.11.006.000.exe`
- `/Users/chad.lampton/Documents/RDPInstalls/DBServers/RDPWinServer5.6.001.6.exe`

The probe script was also fixed locally on 2026-04-13:

- `scripts/Invoke-RDPWinLabProbe.ps1`
- the installed-software collector now tolerates uninstall-registry entries that do not expose `DisplayName`
- a later rerun succeeded without `error_installed_software.json`

## Working Assumption

Build one fresh Windows test server, install/configure `RDPWin`, and learn the minimum repeatable setup needed for later AVD session-host automation.

This is explicitly a test/proving host. It does not need to model the final AVD design. It should be close enough to today's RDP/TERM behavior to answer `RDPWin` install, launch, routing, backend access, user-state, and printing questions.

Near-term test direction has changed. The repo now supports building a separate
Azure-hosted `DBTEST01` backend server for discovery so the session host can be
tested against an Azure-side UNC/share layout instead of relying on retained
Liquid Web database paths.

Azure-side discovery environment decisions are now fixed for the first lab host:

- subscription: `platform-sandbox`
- resource group: `rg-rdp-discovery-test`
- VNet: `vnet-rdp-discovery-test`
- subnet: `snet-rdp-discovery-sessionhosts`
- host pool: `hp-rdp-discovery-test`
- app group: `rag-rdp-discovery-test`
- workspace: `ws-rdp-discovery-test`
- Azure VM name: `rdp-discovery-01`
- Windows computer name: `RDPDISC01`
- initial OS target: Windows Server 2022

Azure-side backend discovery environment decisions are now also fixed:

- Azure VM name: `db-test-01`
- Windows computer name: `DBTEST01`
- private IP: `10.210.10.5`
- data volume: `F:`
- root path: `F:\RDPDiscovery`
- hidden share names:
  - `RDPAPPS$`
  - `RDPCONFIG$`
  - `RDPDATA$`

## Why This Repo Exists

The production infrastructure repo is moving toward Azure Virtual Desktop, but key `RDPWin` packaging/configuration questions are still open. Before baking `RDPWin` assumptions into AVD session-host automation, we need a controlled fresh Windows host where `RDPWin` can be installed and tested without cloning a legacy terminal server.

## Related Local Workspaces

- production AVD infrastructure repo:
  - `/Users/chad.lampton/Documents/repo/rdp-avd-fshosted`
- local-only restart note inside that repo:
  - `/Users/chad.lampton/Documents/repo/rdp-avd-fshosted/HANDOFF.md`
- original soft discovery folder:
  - `/Users/chad.lampton/Documents/rdp-soft-discovery`
- strongest discovery summary:
  - `/Users/chad.lampton/Documents/rdp-soft-discovery/RDP_INFRASTRUCTURE_DISCOVERY_CONSOLIDATED_REPORT.typ`
- RDPWin-focused discovery notes:
  - `/Users/chad.lampton/Documents/rdp-soft-discovery/docs/RDPWIN_NOTES.md`

## Current Discovery Facts To Preserve

- Customer users currently receive an app-like session, not a broad desktop.
- Current customer launch is controlled by GPO behavior named `StartRDPWin`.
- Current confirmed executable path:
  - `C:\ProgramData\ResortDataProcessing\RDPWin\RDPWin5Client\RDPWin.exe`
- Closing `RDPWin.exe` currently logs off the customer session.
- Support users currently receive a separate full-desktop workflow.
- `TERM01` and `TERM03` align to `DB01`.
- `TERM02`, `TERM04`, and likely `TERM06` align to `DB02`.
- `DB01` and `DB02` are retained backend/payment-path systems.
- `IRM01` depends on `DB01`; `IRM02` depends on `DB02`.
- Existing terminal hosts show version/artifact drift; do not assume any one terminal host is a clean image baseline.
- Working direction is MSI/package-based `RDPWin` install on a fresh host, not cloning an old TERM server.
- Stephen White is the named owner for providing `RDPWin`, Actian Zen client, and any helper launcher/interface install media.
- install media is now staged locally in `/Users/chad.lampton/Documents/RDPInstalls`
- Actian client version and config may matter.
- UNC/share launch paths may matter.
- Each Logo has its own independent Actian Zen database.
- Each Logo maintains its own `users.dat` file inside that Logo-specific Zen database.
- The initial file directory share on `DB01` or `DB02` is selected programmatically from the user's AD group membership.
- After that starting share or directory is established, the user can choose which DB to log into inside the application.
- AD group membership is therefore a real dependency in the current design.
- UNC/share access to retained `DB01` / `DB02` paths is therefore a real dependency in the current design.
- The current routing explanation is now clearer:
  - SMB/UNC share access is granted through AD security groups
  - the user logs into the server and is allowed access to either the `DB01` or `DB02` path based on AD group membership
  - folders are created manually
  - folder permissions are assigned manually
  - those folders are tied back to AD security groups
- Database-routing logic is now partially closed: initial path selection is AD-group-driven, but the exact component implementing that lookup still needs to be identified.
- Questionnaire response from Stephen confirms current environment assumptions are still classic-AD oriented:
  - classic AD and GPO are believed to be in use
  - UNC shares, launch paths, and database access are AD-integrated
  - current DB01-hosted UNC launch paths must remain available on day one of the AVD rollout
  - UNC/file-share connectivity between terminal servers and `DB01` / `DB02` is required for `RDPWin` to work
- Questionnaire response also confirms intended user-state behavior:
  - pilot is expected to be non-persistent
  - production is also expected to be non-persistent unless another requirement is later discovered
  - no known roaming profile, printer, cache, or app-state requirement was identified in the questionnaire
- Questionnaire response indicates production intent is to recreate the environment in Azure rather than keep Azure-to-Liquid-Web connectivity long term.
- Broad per-user `RDPWin` profile state has not been proven, but no broad user-state hit was found in the light probe.

## Still To Decide

- whether the first host should stay Entra-joined for testing or whether classic AD-domain-join is required earlier because of AD-group-driven share/path selection
- which network path should be used to reach `DB01` / `DB02`
- whether the first test targets `DB01`, `DB02`, or both
- whether the questionnaire answer "none" for Azure-to-Liquid-Web routing reflects final migration intent only, or whether the approved Azure test-user/test-database path still depends on retained AD, UNC, or other hybrid connectivity during discovery
- authoritative `RDPWin` installer/package path
- required Actian/client/ODBC setup
- exact post-install configuration steps for `RDPWin`
- exact component that performs the AD-group-to-share/path lookup
- whether app-side MFA exists inside `RDPWin`, and if so how it is implemented
- exact meaning of the questionnaire answer "Installshield" for the authoritative installer:
  - package file name
  - version
  - owner
  - silent install method
- reconcile questionnaire answer "None" for post-install steps with other discovery evidence showing host-specific paths, UNC dependencies, and DB selection behavior
- reconcile questionnaire answer "manual control by remote desktop connection configuration" with the newer finding that initial share selection is AD-group-driven and users can later choose a DB in the app
- exact non-production test identity model:
  - Azure test user
  - app-side user, if separate
  - test Logo / test database
  - expected AD group mapping

## Current Pause Point

The Azure discovery environment has already been planned and deployed. Bastion admin access to the Windows host has also been confirmed. The next work starts on the Windows side.

We are stopped after:

1. building the Azure lab automation scaffold
2. adding lint and validation guardrails
3. fixing local lint findings
4. updating stale docs to match the current repo state
5. creating `inventories/group_vars/all.yml`
6. running `playbooks/plan_lab.yml` successfully
7. running `playbooks/deploy_lab.yml` successfully
8. creating the Azure discovery environment and session host VM
9. confirming AVD session-host registration from inside the VM
10. confirming Bastion access to the Windows host
11. capturing new routing and identity findings from discovery notes
12. wiring `DBTEST01` into Terraform and Ansible
13. deploying `db-test-01` / `DBTEST01` into the same Azure lab footprint
14. confirming `DBTEST01` is running with private IP `10.210.10.5`
15. bootstrapping `DBTEST01` with `F:\RDPDiscovery` and the hidden SMB shares
16. applying Entra VM login RBAC on both VMs for `chad.lampton@fullsteamhosted.com`
17. confirming SMB/UNC access from `RDPDISC01` to the three `DBTEST01` hidden shares
18. fixing the probe installed-software collector and confirming a later rerun completed without collector errors

We have not yet:

- installed Actian or `RDPWin` on the Windows host
- run a clean `Baseline` probe on the deployed host using `DBTEST01` plus explicit `-SharePaths`
- proven whether Entra-joined-only is viable once AD-group-driven share selection is exercised
- loaded an approved non-production Actian Zen data set onto `DBTEST01`
- reconciled the new questionnaire answers against earlier discovery notes where they appear to conflict
- confirmed the exact end-to-end lab test identity:
  - AVD sign-in user
  - app-side user, if separate
  - test Logo / test database
  - expected AD group mapping
- exact test details for the non-production path:
  - Azure test user
  - test database
  - any required test-side server/share/path mapping

## Deployment Readiness

The base Azure lab is deployed and ready for the next operational sequence:

1. assign Azure RBAC for Entra VM sign-in if not already assigned:
   - `Virtual Machine User Login` or `Virtual Machine Administrator Login`
2. access `RDPDISC01` and `DBTEST01` through Bastion or the approved admin path
3. verify UNC access from `RDPDISC01` to `\\DBTEST01\RDPAPPS$`, `\\DBTEST01\RDPCONFIG$`, and `\\DBTEST01\RDPDATA$`
4. run the `Baseline` probe on `RDPDISC01`
5. install Actian client
6. run the `AfterActian` probe
7. install and configure `RDPWin`
8. run the `AfterRDPWinInstall`, `AfterConfig`, and `LaunchSmoke` probes
9. capture login, backend selection, share/path, and auth behavior

For `DBTEST01`, the current post-deploy sequence is:

1. VM deployed through `playbooks/deploy_lab.yml`
2. `playbooks/configure_dbserver.yml` completed
3. attached data disk initialized to `F:`
4. `F:\RDPDiscovery` folder/share layout created from the repo manifest

## Questionnaire Intake Summary

Stephen returned the dependency questionnaire on 2026-04-09. High-signal points from that response:

- Liquid Web side connectivity is owned by Stephen with Liquid Web support.
- Liquid Web firewall changes are approved by Ron and Stephen; Azure-side approver is still unknown.
- DNS changes are owned by Ron and Stephen.
- Final disputed design call goes to Ron.
- Long-term goal is no Azure-to-Liquid-Web connectivity, but a temporary site-to-site VPN may still speed up data transfer.
- Questionnaire marked Azure-to-Liquid-Web routing as "none" and production-only VPN need, which conflicts with the current discovery-host test pattern and needs explicit reconciliation.
- Current server names such as `DB01`, `DB02`, `DB04`, `TERM01`, `TERM02`, `TERM03`, `TERM04`, and `TERM06` were called out as naming references; some external-facing names may need to change.
- Classic AD and GPO are believed to be in use today.
- UNC shares, launch paths, and database access are AD-integrated.
- `RDPWin` is said to require host-specific naming, paths, UNC locations, or local configuration.
- Current DB01-hosted UNC launch paths are required on day one of AVD rollout.
- UNC path connectivity between terminal servers and data servers is required.
- Pilot and production were both described as non-persistent, with no known roaming profile or printer-state need.

Items from the questionnaire that are useful but still too weak to treat as closed:

- `Installshield` as the installer answer is not enough; actual package, version, owner, and install command are still needed.
- Stephen White has been identified as the installer owner, but exact package names and versions are still needed.
- `None` for post-install steps conflicts with other evidence and needs to be verified on the fresh host.
- `We manually control this by remote desktop connection configuration` conflicts with the newer AD-group-driven share-selection finding and needs reconciliation.
- `Unknown` remains on Azure network ownership, Azure firewall approval, routing ownership, and Entra-joined compatibility.
- New meeting clarification: do not test the Azure discovery host against retained production dependencies. Use an Azure test user and a test database path when those are available.

## First Test Objective

The first successful milestone is not “production-ready AVD.”

The first successful milestone is:

1. a fresh Windows host exists
2. required network path to selected backend exists
3. required identity/authentication mode is known
4. authoritative `RDPWin` installer is available outside git
5. install procedure is documented
6. `RDPWin.exe` launches
7. tester can prove whether login/routing hits the intended backend
8. required missing components are captured as a short punch list

## Probe Workflow

Copy `scripts/Invoke-RDPWinLabProbe.ps1` to the Windows test host or copy this repo there.

Suggested phases:

1. `Baseline`
2. `AfterActian`
3. `AfterRDPWinInstall`
4. `AfterConfig`
5. `LaunchSmoke`

Baseline example:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\scripts\Invoke-RDPWinLabProbe.ps1 -Phase Baseline -TargetHosts DB01,DB02
```

Launch-monitor example:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\scripts\Invoke-RDPWinLabProbe.ps1 -Phase LaunchSmoke -TargetHosts DB01,DB02 -MonitorRDPWinSeconds 180
```

Default Windows output root:

`C:\Temp\RDPWinLab\<COMPUTERNAME>\<Phase>_<timestamp>`

## Working Local Commands

Current local lint/validation path is working and uses repo-local tooling:

- `.venv/bin/ansible-lint`
- `.venv/bin/yamllint inventories playbooks roles .github .ansible-lint .yamllint`
- `tofu -chdir=terraform fmt -check -recursive`
- `tofu -chdir=terraform validate`
- `./.tools/bin/tflint --init --chdir terraform`
- `./.tools/bin/tflint --recursive --chdir terraform`

## Next Step

The next Codex session should not spend time on more Terraform scaffolding.

The immediate next steps are:

1. confirm Entra sign-in RBAC for the test user on `rdp-discovery-01` and `db-test-01`
2. verify UNC/share access from `RDPDISC01` to `DBTEST01`
3. run the Windows-side `Baseline` probe on `RDPDISC01`
4. begin Actian and `RDPWin` discovery against the Azure-hosted backend
