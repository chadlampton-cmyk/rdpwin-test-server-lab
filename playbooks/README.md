# Playbooks

These playbooks are the Ansible entrypoints for the Azure-hosted RDPWin lab.

- `plan_lab.yml`
  - runs preflight checks, writes generated tfvars, and executes `tofu plan`
- `deploy_lab.yml`
  - runs the same preflight checks and executes `tofu apply`
- `plan_sessionhost_rebuild.yml`
  - runs a targeted `tofu plan` for `rdp-discovery-01` and its AVD registration
    path without targeting `db-test-01`
- `deploy_sessionhost_rebuild.yml`
  - runs the same targeted path and applies only the discovery session-host
    rebuild resources
- `configure_dbserver.yml`
  - uses Azure VM Run Command to initialize the `DBTEST01` data disk and apply
    the repo layout/share script without requiring WinRM

## Usage

Plan:

```bash
ansible-playbook playbooks/plan_lab.yml
```

Plan session-host rebuild only:

```bash
ansible-playbook playbooks/plan_sessionhost_rebuild.yml
```

Deploy:

```bash
ansible-playbook playbooks/deploy_lab.yml
```

Deploy session-host rebuild only:

```bash
ansible-playbook playbooks/deploy_sessionhost_rebuild.yml
```

Configure `DBTEST01` after deploy:

```bash
ansible-playbook playbooks/configure_dbserver.yml
```

## Notes

- apply is controlled by the playbook entrypoint, not the example inventory
- this repo is for the test lab only, not the production RDP AVD platform
- `configure_dbserver.yml` runs from `localhost` through Azure CLI and keeps the
  repo on the same operator model used by the Terraform wrapper
