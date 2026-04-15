# Architecture

## Purpose

This repo manages a narrow Azure-hosted lab for testing `RDPWin` on a fresh
AVD-style session host with a temporary Azure-hosted backend server.

## Active Components

- Ansible for operator workflow
- OpenTofu for Azure resources
- Azure resource group, VNet, subnet, NSG, optional NAT
- AVD pooled host pool
- AVD RemoteApp application group with an `RDPWin` app definition
- AVD desktop application group for desktop-session testing
- AVD workspace associated to both app groups
- one Windows Server 2022 discovery session host VM
- one Windows Server 2022 `DBTEST01` backend VM in the same RG/VNet/subnet
- `AADLoginForWindows` on both Windows VMs
- optional VM login RBAC assignments on both Windows VMs
- optional AVD user assignments on the workspace app groups
- post-deploy Ansible bootstrap path for `DBTEST01` using Azure VM Run Command
- managed data disk and enterprise-style `F:\RDPDiscovery` share layout on
  `DBTEST01`

## Current User-Path Model

- admin path:
  - Bastion/direct admin access with `localadmin`
- user path:
  - Windows App / AVD

The current design direction is no longer Bastion-first for user validation.

## Current Known Limitation

`RDPWin` is currently functional in a full desktop session on `RDPDISC01`, but
it is not yet functional as a pure RemoteApp. The likely production-like model
for this lab is therefore:

- AVD desktop session
- local policy / scripted startup behavior
- auto-launch `RDPWin`
- app-like UX on top of a desktop session

Additional current constraint:

- `explorer.exe` should remain running
- shell replacement and aggressive Start/taskbar restriction attempts caused
  instability during testing
- no supported local GPO was found for “disable left-click Start but keep
  right-click Start”

## Not Managed Here

- retained Liquid Web VPN connectivity
- final production `rdp-avd-fshosted` design
- `RDPWin` installer/package artifacts
- Actian installer/package artifacts
- customer data or credentials
- production identity modernization decisions beyond this discovery lab

## Boundary With Other Repos

- this repo: Azure-hosted `RDPWin` lab environment and Windows-side probe
- `rdp-avd-fshosted`: production-oriented RDP AVD infrastructure
- `saw-avd-fshosted`: reference implementation for operator and Terraform
  patterns
