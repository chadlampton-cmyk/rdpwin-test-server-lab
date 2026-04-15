# Terraform (OpenTofu) Layout

This directory contains the Azure infrastructure definition for the `RDPWin`
lab.

## What It Builds

- one Azure resource group
- one VNet and session-host subnet
- optional NAT gateway for outbound access
- one pooled AVD host pool
- one RemoteApp application group
- one desktop application group when enabled
- one workspace associated to the configured app groups
- one Windows Server 2022 discovery session host VM
- `AADLoginForWindows` on the discovery session host when enabled
- AVD agent registration extension
- one Windows Server 2022 `DBTEST01` backend VM
- optional managed data disk for `DBTEST01`
- `AADLoginForWindows` on `DBTEST01` when enabled
- optional VM login RBAC assignments
- optional AVD user assignments to the app groups

## What It Does Not Do

- install `RDPWin`
- install Actian / Zen client
- configure retained VPN connectivity
- solve DB01 / DB02 routing
- guarantee that `RDPWin` is pure-RemoteApp compatible

Those remain lab/test steps after the VM is reachable.
