# Architecture

## Purpose

This repo manages a narrow Azure-hosted lab for testing `RDPWin` on a fresh
AVD-style session host with a temporary Azure-hosted backend server.

## Active Components

- Ansible for operator workflow
- OpenTofu for Azure resources
- Azure resource group, VNet, subnet, NSG, optional NAT
- AVD pooled host pool
- RemoteApp application group with an `RDPWin` app definition
- AVD workspace
- one Windows Server 2022 discovery session host VM
- one Windows Server 2022 `DBTEST01` backend VM in the same RG/VNet/subnet
- `AADLoginForWindows` on both Windows VMs so the lab can use Entra VM sign-in
- optional Entra RBAC assignments on both Windows VMs for test login principals
- a post-deploy Ansible bootstrap path for `DBTEST01` using Azure VM Run Command
- a managed data disk and enterprise-style `F:\RDPDiscovery` share layout on `DBTEST01`

## Not Managed Here

- retained Liquid Web VPN connectivity
- final production `rdp-avd-fshosted` design
- `RDPWin` installer/package artifacts
- Actian installer/package artifacts
- customer data or credentials
- production identity modernization decisions beyond this discovery lab

## Boundary With Other Repos

- this repo: Azure-hosted RDPWin lab environment and Windows-side probe
- `rdp-avd-fshosted`: production-oriented RDP AVD infrastructure
- `saw-avd-fshosted`: reference implementation for operator and Terraform patterns
