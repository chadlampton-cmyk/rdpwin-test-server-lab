# Validation

Last updated: 2026-04-21.

## Static Checks

Run these before pushing changes:

```bash
ansible-playbook --syntax-check playbooks/plan_lab.yml
ansible-playbook --syntax-check playbooks/deploy_lab.yml
ansible-playbook --syntax-check playbooks/configure_dbserver.yml
.venv/bin/ansible-lint
.venv/bin/yamllint inventories playbooks roles .github .ansible-lint .yamllint
tofu -chdir=terraform fmt -check -recursive
tofu -chdir=terraform init -backend=false
tofu -chdir=terraform validate
./.tools/bin/tflint --init --chdir terraform
./.tools/bin/tflint --recursive --chdir terraform
```

## Azure Lab Validation

After apply, validate:

- resource group exists
- VNet and subnet exist
- host pool exists
- RemoteApp app group exists
- desktop app group exists when enabled
- workspace exists
- session host VM exists
- DB server VM exists
- session host has the `AADLoginForWindows` extension in succeeded state
- session host is registered to the host pool
- session host status is `Available`
- expected VM login RBAC assignments exist
- expected AVD user assignments exist
- `DBTEST01` data disk is online and formatted
- `DBTEST01` folder/share layout exists
- `DBTEST01` is running
- no `Microsoft.AAD/domainServices` resource exists yet for the active lab

Examples:

```bash
az group show --name "<resource-group-name>" -o yaml
az desktopvirtualization hostpool show -g "<resource-group-name>" -n "<host-pool-name>" -o yaml
az desktopvirtualization applicationgroup list -g "<resource-group-name>" -o yaml
az desktopvirtualization workspace show -g "<resource-group-name>" -n "<workspace-name>" -o yaml
az vm extension show --resource-group "<resource-group-name>" --vm-name "<sessionhost-vm-name>" --name "<sessionhost-vm-name>-aadlogin" -o yaml
az role assignment list --all --assignee "<user-or-group>" -o table
az rest --method get --url "https://management.azure.com/<session-host-collection-url>?api-version=2024-04-03" -o yaml
```

## AVD Session Host Validation

For `RDPDISC01`, confirm:

- `status: Available`
- `updateState: Succeeded`
- `SxSStackListenerCheck: HealthCheckSucceeded`
- `AADJoinedHealthCheck: HealthCheckSucceeded`

Important repair history:

- if the session host becomes `Unavailable` with an SxS stack error, check
  whether `RDS-RD-Server` is installed on the VM

## DB Server Validation

For `DBTEST01`, validate through Bastion or Azure Run Command as well:

- `Get-Volume -DriveLetter F`
- `Test-Path 'F:\RDPDiscovery'`
- `Get-SmbShare -Name RDPAPPS$,RDPCONFIG$,RDPDATA$`

Current caution:

- share existence on `DBTEST01` does not prove that end-user UNC authorization
  is working
- the current standalone `DBTEST01` cannot reliably resolve Entra-only
  principals for SMB / NTFS ACL enforcement
- the `RDPNT1000/2000/3000` groups currently on `DBTEST01` should be treated as
  placeholders until `Microsoft Entra Domain Services` is deployed and the
  server is domain-joined

## RDPWin Validation

Current expected state:

- `RDPWin` launches from the desktop-shaped AVD session
- pure RemoteApp still fails after logon
- the Zen temporary license issue was fixed, but that did not change the
  RemoteApp failure

Current backend findings to validate:

- `Actian Zen Cloud Server` is running
- `RDPWin Monitor GDS Reservations` is running
- the Zen temporary license was directly shown as `Expired` on `2026-04-15`
- the Zen license was reactivated afterward
- `Btrieve Error 161` cleared after the license fix
- RemoteApp still fails, so the license issue was not the RemoteApp root cause

Current session-shaping findings to validate:

- `RDPWin` auto-launches from the desktop session
- closing `RDPWin` logs off the session
- `Server Manager` is suppressed at logon
- aggressive Start/taskbar restrictions were rolled back
- `explorer.exe` is intentionally left running
- current `HKLM Run` launcher behavior is not consistent across all Entra users

Current external-tenant identity findings to validate:

- `avdtest01@fscaptest.onmicrosoft.com` was created as a tenant-local internal
  user
- no Entra role results in `AADSTS500208`
- `Guest Inviter` clears `AADSTS500208` but does not allow MFA registration
- `Message Center Reader` allows MFA registration and AVD sign-in
- `Message Center Reader` is the current minimum tested working role
- `Message Center Reader` should be treated as a workaround under evaluation,
  not final proof of a PCI-clean customer-user design

PCI-aligned validation should also confirm:

- dedicated non-admin Entra users receive the app-first session behavior
- admin users do not
- the chosen logon trigger runs consistently across users
- the launch/logoff control leaves a usable audit trail
- the external-tenant user path does not require a broader Entra role than is
  strictly necessary
- the backend UNC model is eventually revalidated after domain-backed SMB
  authorization is implemented

Use:

- [docs/TEST_PLAN.md](/Users/chad.lampton/Documents/repo/rdpwin-test-server-lab/docs/TEST_PLAN.md)
- [scripts/Invoke-RDPWinLabProbe.ps1](/Users/chad.lampton/Documents/repo/rdpwin-test-server-lab/scripts/Invoke-RDPWinLabProbe.ps1)
