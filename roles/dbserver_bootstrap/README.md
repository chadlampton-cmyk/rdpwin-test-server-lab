# dbserver_bootstrap

Bootstraps the Azure `DBTEST01` Windows VM after Terraform deployment.

This role runs on `localhost` and uses `az vm run-command invoke` so the repo
does not need a separate WinRM management path.

What it does:

- verifies Azure CLI access
- verifies the target VM exists
- initializes and formats the attached data disk to `F:`
- copies the repo layout manifest and PowerShell builder onto the VM
- runs `scripts/New-DBTEST01Layout.ps1`
- optionally creates SMB shares from the manifest

Entry point:

- `playbooks/configure_dbserver.yml`
