# Validation

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

## RDPWin Validation

Current expected state:

- `RDPWin` works in a full desktop session
- pure RemoteApp currently fails after logon

Use:

- [docs/TEST_PLAN.md](/Users/chad.lampton/Documents/repo/rdpwin-test-server-lab/docs/TEST_PLAN.md)
- [scripts/Invoke-RDPWinLabProbe.ps1](/Users/chad.lampton/Documents/repo/rdpwin-test-server-lab/scripts/Invoke-RDPWinLabProbe.ps1)
