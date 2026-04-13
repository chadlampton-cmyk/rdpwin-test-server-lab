# `lab_tofu` Role

This role is the Ansible wrapper for the Azure-hosted RDPWin test lab.

Responsibilities:

- validate required tools and Azure login
- enforce optional subscription guardrails
- resolve the session-host admin password from inventory or `SESSIONHOST_ADMIN_PASSWORD`
- write `terraform/ansible.auto.tfvars.json`
- run `tofu init`, `tofu validate`, `tofu plan`, and `tofu apply`
- show the deployment context before execution

## Entry Points

- `playbooks/plan_lab.yml`
- `playbooks/deploy_lab.yml`

## Notes

- this role provisions the Azure lab platform only
- it does not install `RDPWin` or Actian
- use the Windows-side probe after the VM is reachable
