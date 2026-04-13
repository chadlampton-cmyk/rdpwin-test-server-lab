# Inventories

This folder defines the local operator input model for the RDPWin Azure lab.

## Files

- `hosts.yml`
  - localhost execution target for Ansible orchestration
- `group_vars/all.example.yml`
  - safe example template
- `group_vars/all.yml`
  - local values, not committed

## Local Setup

```bash
cp inventories/group_vars/all.example.yml inventories/group_vars/all.yml
export SESSIONHOST_ADMIN_PASSWORD='StrongPasswordHere'
```

Then update `all.yml` with the Azure names, CIDRs, and environment values you actually want to use.

## Input Groups

- OpenTofu controls
- Azure resource naming
- address space and DNS
- AVD control plane naming
- session host VM settings
- optional tags

Retained backend addresses and routing assumptions are still operational notes for
the lab. They are not Terraform inputs in the current repo shape.

The `lab_tofu` role converts the values in `all.yml` into a temporary
`terraform/ansible.auto.tfvars.json` file before `tofu plan` or `tofu apply`.
