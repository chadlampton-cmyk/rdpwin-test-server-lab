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

GitHub Actions also runs:

- Ansible and YAML lint
- OpenTofu format and validate
- TFLint
- tfsec

Notes:

- `ansible-lint` and `yamllint` are expected to run from the repo-local `.venv`
- `tflint` is expected to run from `./.tools/bin/tflint`
- avoid `yamllint .` after creating `.venv/`, because it will recurse into tool-installed packages

## Azure Lab Validation

After apply, validate:

- resource group exists
- VNet and subnet exist
- host pool exists
- RemoteApp app group exists
- workspace exists
- session host VM exists
- DB server VM exists
- session host has the `AADLoginForWindows` extension in succeeded state
- session host is registered to the host pool
- expected Entra VM login RBAC assignments exist on both VMs
- `DBTEST01` data disk is online and formatted
- `DBTEST01` folder/share layout exists
- `DBTEST01` is running
- `DBTEST01` has the `AADLoginForWindows` extension in succeeded state

Examples:

```bash
az group show --name "<resource-group-name>" -o yaml
az vm show --resource-group "<resource-group-name>" --name "<sessionhost-vm-name>" -o yaml
az vm show --resource-group "<resource-group-name>" --name "<dbserver-vm-name>" -o yaml
az vm extension show --resource-group "<resource-group-name>" --vm-name "<sessionhost-vm-name>" --name "<sessionhost-vm-name>-aadlogin" -o yaml
az role assignment list --scope "$(az vm show --resource-group "<resource-group-name>" --name "<sessionhost-vm-name>" --query id -o tsv)" -o table
az vm get-instance-view --resource-group "<resource-group-name>" --name "<dbserver-vm-name>" --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus | [0]" -o tsv
az vm extension show --resource-group "<resource-group-name>" --vm-name "<dbserver-vm-name>" --name "<dbserver-vm-name>-aadlogin" -o yaml
az role assignment list --scope "$(az vm show --resource-group "<resource-group-name>" --name "<dbserver-vm-name>" --query id -o tsv)" -o table
az resource list --resource-group "<resource-group-name>" --resource-type Microsoft.DesktopVirtualization/hostPools/sessionHosts -o table
```

If the generic Azure resource list does not show the session host cleanly, validate from inside the VM as well:

- `HKLM:\SOFTWARE\Microsoft\RDInfraAgent` shows `IsRegistered : 1`
- `HostPoolId` is populated
- `AgentState : 11`
- `RdAgent` service is running
- `RDAgentBootLoader` service is running

For `DBTEST01`, validate through Bastion or Azure Run Command as well:

- `Get-Volume -DriveLetter F`
- `Test-Path 'F:\RDPDiscovery'`
- `Get-SmbShare -Name RDPAPPS$,RDPCONFIG$,RDPDATA$`

## RDPWin Validation

After the VM is reachable through Bastion, use:

- [docs/TEST_PLAN.md](/Users/chad.lampton/Documents/repo/rdpwin-test-server-lab/docs/TEST_PLAN.md)
- [scripts/Invoke-RDPWinLabProbe.ps1](/Users/chad.lampton/Documents/repo/rdpwin-test-server-lab/scripts/Invoke-RDPWinLabProbe.ps1)
