# DBTEST01 Design

## Purpose

`DBTEST01` is the planned Azure-hosted discovery database and file server for the
temporary `RDPWin` test environment.

This server is intended to close the gap between a session-host-only lab and a
more realistic backend dependency model for `RDPWin` testing.

## Design Goal

Keep the session host as Entra-centered as possible while moving the file share
and non-production database dependencies into Azure for discovery.

This is still not the final production design. It is a discovery host used to
answer:

- what file and share layout `RDPWin` expects
- what Actian Zen data layout must exist
- what config artifacts must be centrally hosted
- how much of the current app path can be reproduced without classic AD

## Recommended Filesystem Layout

Use a dedicated data volume when available.

Recommended root:

```text
F:\RDPDiscovery
```

Recommended top-level layout:

```text
F:\RDPDiscovery
  Apps
  Data
  Shares
  Ops
  Staging
  Backups
```

### `Apps`

Purpose:
Store packaged application assets and installer material that may need to be
referenced by the TERM discovery host or the DB server itself.

Recommended children:

- `Apps\RDPWin\Client`
- `Apps\RDPWin\Config`
- `Apps\ActianZen\Client`
- `Apps\ActianZen\Utilities`

### `Data`

Purpose:
Store the non-production Actian Zen data sets and shared discovery data.

Recommended children:

- `Data\Logos`
- `Data\Logos\_Template\Database`
- `Data\Logos\_Template\Users`
- `Data\Logos\_Template\Exports`
- `Data\Shared`

Operational rule:
Create one child under `Data\Logos` per approved non-production logo or test
database copy once the real names are known.

Example:

```text
Data\Logos\LOGO01\Database
Data\Logos\LOGO01\Users
Data\Logos\LOGO01\Exports
```

### `Shares`

Purpose:
Separate the published UNC presentation layer from the raw data layout.

Recommended share roots:

- `Shares\RDPApps`
- `Shares\RDPConfig`
- `Shares\RDPData`

Recommended hidden share names:

- `RDPAPPS$`
- `RDPCONFIG$`
- `RDPDATA$`

Example UNC patterns:

```text
\\DBTEST01\RDPAPPS$
\\DBTEST01\RDPCONFIG$
\\DBTEST01\RDPDATA$
```

Design rule:
Do not publish the entire raw `Data` tree directly unless discovery proves that
the app requires that shape. Keep the share layer controlled.

### `Ops`

Purpose:
Keep operator evidence and support material off the application data paths.

Recommended children:

- `Ops\Logs`
- `Ops\ProbeOutput`
- `Ops\Scripts`
- `Ops\ConfigExports`

### `Staging`

Purpose:
Provide a quarantine-style landing zone for approved non-production data,
installers, or exported evidence.

Recommended children:

- `Staging\Inbound`
- `Staging\Outbound`

### `Backups`

Purpose:
Hold manual backups created during discovery before risky changes or data
mutation tests.

Recommended children:

- `Backups\Manual`
- `Backups\Exports`

## Enterprise-Level Rules

- keep application binaries, hosted data, operational logs, and staging media in separate roots
- keep published shares separate from the raw data directory tree
- do not use `C:` as the long-term data root unless a temporary exception is required
- avoid `D:` on Azure Windows VMs because it is commonly the temporary disk
- use hidden shares for backend testing unless a visible share is explicitly needed
- do not place installer packages directly inside the live data tree
- do not mix probe output with the hosted application data set
- treat each logo or test database copy as an isolated folder under `Data\Logos`

## Manifest And Build Script

This repo now includes:

- `config/dbtest01-layout.json`
- `scripts/New-DBTEST01Layout.ps1`

Preview the layout without making changes:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\scripts\New-DBTEST01Layout.ps1 -WhatIf
```

Create the base folder tree:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\scripts\New-DBTEST01Layout.ps1
```

Create the base folder tree and hidden SMB shares:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\scripts\New-DBTEST01Layout.ps1 -CreateShares
```

Example with explicit share ACL inputs:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\scripts\New-DBTEST01Layout.ps1 `
  -CreateShares `
  -ShareFullAccess 'Administrators' `
  -ShareChangeAccess 'localadmin'
```

## Current Known Limits

This design does not close:

- the final non-production Actian Zen data set source
- the exact logo names or data copies to host
- the final UNC paths expected by `RDPWin`
- whether classic AD group-based path selection must be reproduced to get a valid test

It does create a clean backend server layout so those questions can be tested in
Azure without reworking the server filesystem each time.
