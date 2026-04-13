# DB Server Module

Creates the Windows VM for the `DBTEST01` discovery database and file server.

Responsibilities:

- create the NIC
- optionally create and attach a dedicated data disk
- optionally enable Entra sign-in via `AADLoginForWindows`

This module is wired into the root Terraform and is part of the deployed
discovery lab footprint.
