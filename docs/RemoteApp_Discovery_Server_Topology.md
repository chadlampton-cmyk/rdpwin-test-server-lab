---
title: "RDPWin Discovery Lab: RemoteApp and Backend Topology"
date: "2026-04-29"
---

# Executive Summary

This document explains the Azure discovery lab built for `RDPWin`, with focus
on:

- the `RDPDISC01` discovery server and its `AVD RemoteApp` setup
- the `DBTEST01` backend database and file-share server
- the staged users, groups, shares, and routing files
- what is inside the `Microsoft Entra Domain Services` design
- what remains outside `Microsoft Entra Domain Services`
- why the final lab shape works
- what is working now versus what is still limited

This is a discovery lab, not the final production design.

# Topology

```text
                               Internet / User Device
                                        |
                                        v
                         +---------------------------------+
                         | Windows App / Azure Virtual     |
                         | Desktop frontend                |
                         | - Entra sign-in                |
                         | - MFA / Conditional Access     |
                         +---------------------------------+
                                        |
                                        v
                         +---------------------------------+
                         | Host Pool: hp-rdp-discovery-test|
                         | App Group: rag-rdp-discovery-   |
                         | test                            |
                         | Published app: RDPWin           |
                         +---------------------------------+
                                        |
                                        v
     +--------------------------------------------------------------------+
     | RDPDISC01 / rdp-discovery-01                                        |
     | Discovery session host                                               |
     | - Windows Server 2022                                                |
     | - AVD session host                                                   |
     | - AADLoginForWindows extension                                       |
     | - RDPWin client install                                              |
     | - Actian Zen client components                                       |
     | - Crystal runtime / VC++ prerequisites                               |
     | - Routing files: RDPWinPath.txt, GroupToServer5.txt                  |
     +--------------------------------------------------------------------+
                                        |
                     SMB / UNC paths + Actian Zen access + backend auth
                                        |
                                        v
     +--------------------------------------------------------------------+
     | DBTEST01 / db-test-01                                               |
     | Backend DB and file server                                          |
     | - Windows Server 2022                                               |
     | - Actian Zen server                                                 |
     | - AADLoginForWindows extension                                      |
     | - Joined to fshostedtest.onmicrosoft.com                            |
     | - Hosts RDPNT1000 / 2000 / 3000 trees                               |
     | - Hosts backend UNC paths used by RDPWin                            |
     +--------------------------------------------------------------------+
                                        |
                                        v
                 +------------------------------------------------+
                 | Microsoft Entra Domain Services                 |
                 | fshostedtest.onmicrosoft.com                    |
                 | DNS/DC IPs: 10.10.10.5, 10.10.10.4             |
                 | Used for backend auth, SMB, and share ACLs     |
                 +------------------------------------------------+
```

# Why This Lab Has Two Servers

`RDPWin` is not just one EXE on one Windows host.

The lab had to prove both of these planes:

- client/session-host behavior on `RDPDISC01`
- backend file-share and database behavior on `DBTEST01`

This split exists because the notes and probes showed that `RDPWin` depends on
both:

- `Actian Zen`
- direct `SMB` / `UNC` path access

Without `DBTEST01`, the team could not prove share reachability, ACL behavior,
per-user backend routing, or whether the app could open the correct database.

# Azure Components Created

The lab includes these main Azure-side components:

- resource group: `externalavd-test-rg`
- host pool: `hp-rdp-discovery-test`
- RemoteApp group: `rag-rdp-discovery-test`
- desktop app group: `dag-rdp-discovery-test`
- workspace: `ws-rdp-discovery-test`
- session host VM: `rdp-discovery-01`
- session host Windows name: `RDPDISC01`
- backend VM: `db-test-01`
- backend Windows name: `DBTEST01`
- `AADLoginForWindows` VM extension on both Windows servers

RemoteApp-specific AVD settings in this repo:

- preferred app group type: `RailApplications`
- published app name: `RDPWin`
- published app path:
  `C:\Program Files\ResortDataProcessing\RDPWinMSI\RDPWin.exe`
- printer redirection enabled in host-pool RDP properties

# Discovery Server: RDPDISC01

## What It Is

`RDPDISC01` is the access-side discovery server. It is the host users reach
through `Windows App` and `AVD`.

Its job is to host the `RDPWin` client runtime and prove whether the app can:

- launch
- authenticate
- reach the correct backend share path
- reach the correct Actian backend
- behave acceptably through AVD

## What Was Installed On It

Confirmed or expected client-side components:

- `RDPWin`
- `Actian Zen` client components
- `Crystal Reports` runtime
- `VC++` runtime packages
- routing text files under `ProgramData`

Important path artifacts:

- `C:\ProgramData\ResortDataProcessing\RDPWin\RDPWinPath.txt`
- `C:\ProgramData\ResortDataProcessing\RDPWin\GroupToServer5.txt`

Published app executable path:

- `C:\Program Files\ResortDataProcessing\RDPWinMSI\RDPWin.exe`

## What It Does In The Test

`RDPDISC01` is where the user session lands.

The server then depends on:

- the AVD control plane to broker the session
- backend authentication to `DBTEST01`
- the routing files to point `RDPWin` at the correct backend tree
- `Actian Zen` client connectivity

# Backend Server: DBTEST01

## What It Is

`DBTEST01` is the Azure-side replacement for the backend database and file tier
used by `RDPWin`.

It stands in for the retained legacy `DB01` / `DB02` style server role.

## What Was Set Up On It

Confirmed server-side design and implementation:

- Windows Server 2022
- `Actian Zen Cloud Server`
- file-share layout for staged tenant testing
- share and `NTFS` permissions tied to staged routing groups
- AAD DS domain join for backend auth

## Backend Folder and Share Layout

Active staged trees:

- `F:\RDPNT1000`
- `F:\RDPNT2000`
- `F:\RDPNT3000`

Active visible shares:

- `\\DBTEST01\RDPNT1000`
- `\\DBTEST01\RDPNT2000`
- `\\DBTEST01\RDPNT3000`

Known backend folder examples:

- `F:\RDPNT1000\RDP\RDP01`
- `F:\RDPNT2000\RDP\RDP02`
- `F:\RDPNT3000\RDP\RDP03`

Earlier bootstrap and discovery layout also included hidden-share concepts:

- `\\DBTEST01\RDPAPPS$`
- `\\DBTEST01\RDPCONFIG$`
- `\\DBTEST01\RDPDATA$`

Those hidden shares were useful during early layout testing, but the notes later
confirmed that the live client routing model depends on direct UNC paths under
the `RDPNT1000/2000/3000` trees.

# Users and Groups

## Staged Users

Current staged tenant users:

- `CSS0@fullsteamhostedtest.onmicrosoft.com`
- `HSC1@fullsteamhostedtest.onmicrosoft.com`
- `TCS2@fullsteamhostedtest.onmicrosoft.com`

## Staged Routing Groups

Current staged groups:

- `RDPNT1000`
- `RDPNT2000`
- `RDPNT3000`

## User-to-Group Mapping

- `CSS0 -> RDPNT1000`
- `HSC1 -> RDPNT2000`
- `TCS2 -> RDPNT3000`

## Why These Groups Exist

These groups are how the lab reproduces the legacy app-routing pattern.

They exist so that:

- each staged user maps to a specific backend tree
- share and `NTFS` permissions can be applied per routing lane
- the app can be forced toward the correct backend folder and database

# Routing Files and Test Files

## Routing Files

The client-side pathing files are the most important test artifacts because they
show where `RDPWin` expects each staged user to land.

Important files:

- `RDPWinPath.txt`
- `GroupToServer5.txt`

Confirmed location:

- `C:\ProgramData\ResortDataProcessing\RDPWin\`

## Confirmed Backend Targets In RDPWinPath.txt

The repo notes confirm these direct UNC targets:

- `\\DBTest01\RDPNT1000\RDP\RDP01 [CSS]`
- `\\DBTest01\RDPNT2000\RDP\RDP02 [HCS]`
- `\\DBTest01\RDPNT3000\RDP\RDP03 [TCS]`

## GroupToServer5.txt Ordering Rule

The notes explicitly call out that this file is order-sensitive:

- `Must match the server drop down order in RDPWinPath5.txt`

Known ordering note:

- `CCS 0`
- `HSC 1`
- `TCS 2`

## Other Useful Test Artifacts

- `scripts/Invoke-RDPWinLabProbe.ps1`
- `scripts/New-DBTEST01Layout.ps1`
- `config/dbtest01-layout.json`

These exist to:

- inventory installs and config drift
- validate shares and services
- capture crash evidence
- recreate the DB backend layout consistently

# Identity Model

## What Is On Microsoft Entra Domain Services

The final backend design moved onto `Microsoft Entra Domain Services`.

Managed domain:

- `fshostedtest.onmicrosoft.com`

Controller/DNS IPs:

- `10.10.10.5`
- `10.10.10.4`

The items that are inside the AAD DS-backed backend model are:

- `DBTEST01` domain join
- `RDPDISC01` backend auth model
- `SMB` share access model for `RDPWin`
- backend `NTFS` permission resolution
- backend `Actian Zen` / app-path auth assumptions
- domain principals such as `FSHOSTEDTEST\RDPNT1000`

## What Is Not On Microsoft Entra Domain Services

These items remain outside AAD DS:

- initial user sign-in to `Windows App`
- `AVD` session brokering
- `Entra ID` MFA and Conditional Access
- AVD application-group assignment
- Azure RBAC on the VM and AVD app groups
- `RDPWin` in-app login and QR/MFA flow
- `localadmin` admin path

Short version:

- `Entra ID` is the edge/front-door identity plane
- `AAD DS` is the backend Windows/SMB/app auth plane

# Why The Earlier Model Failed

The earlier experiment mixed:

- an Entra-joined `RDPDISC01`
- an AAD DS-joined `DBTEST01`

That design did not give seamless backend access.

Why it failed:

- the user could sign in to AVD successfully
- the backend share existed
- the ACLs existed
- but silent `SMB` single sign-on did not happen

Evidence from the notes:

- `Cloud Kerberos enabled by policy: 0`
- no cached cloud tickets for seamless backend auth
- Windows prompted for credentials when the user hit `\\DBTEST01\RDPNT1000`
- explicit `fshostedtest\CSS0` auth worked

That proved the gap was not:

- missing shares
- missing folders
- missing app data
- or missing ACLs

It was the backend auth model itself.

# Why The Final Model Works

The final lab direction works because it reproduces the pieces `RDPWin`
actually appears to need.

## 1. Entra At The Edge

Users enter through:

- `Windows App`
- `AVD`
- `Entra ID`
- `MFA`

This keeps the user-facing entry model modern and controlled.

## 2. AAD DS On The Backend

Both Windows servers use the managed-domain backend model for:

- `SMB`
- `NTFS`
- `RDPWin` share access
- `Actian Zen` / app-path backend assumptions

This is what let the backend behave like the older AD-dependent environment.

## 3. Correct Share and NTFS ACLs

The app would not open reliably until the `RDPNT1000/2000/3000` trees were
permissioned consistently.

That matters because `RDPWin` is sensitive to even small access problems on the
target share path.

## 4. Correct Routing Files

The routing files are not cosmetic.

They point the app to the actual backend tree, and the order in
`GroupToServer5.txt` matters.

## 5. Backend Zen and Share Layers Both Matter

This lab proved that `Actian Zen` alone is not the whole app path.

`RDPWin` also depends on:

- direct `UNC` pathing
- share access
- path-specific backend layout

# RemoteApp Status

## What Is Working

The `RemoteApp` plumbing is now in place:

- host pool is configured for `RailApplications`
- `RDPWin` is published as a `RemoteApp`
- the AVD session host is healthy and available
- user assignment to the RemoteApp group can be granted through Azure RBAC

Also working in the broader lab:

- `RDPWin` opens against the correct backend database per staged user
- the backend share and ACL model works under the final AAD DS-backed backend
  design
- printer redirection is enabled at the AVD host-pool layer

## What Is Still Limited

Historically, pure `RDPWin` `RemoteApp` has not been stable.

Observed behavior in the notes:

- the user reaches Windows `Welcome`
- the profile loads
- the session exits almost immediately

Important conclusion:

- the Zen license issue was real but not the root cause
- the app appears to have session-shell or runtime assumptions that are present
  in a desktop session but not cleanly present in pure `RemoteApp`

So the infrastructure and publication model work, but pure `RDPWin RemoteApp`
compatibility is still an application-side question.

# Printer Redirection

Printing is configured as normal `RDP` printer redirection through `AVD`.

In this repo:

- `redirectprinters:i:1` is enabled in the host-pool custom RDP properties

Meaning:

- the local client printer is redirected into the remote session
- `RDPWin` prints to the redirected printer
- this is not a separate server-side print-server design
- this is not `Universal Print`

# Operator Checklist

If this lab has to be rebuilt or explained quickly, the key facts are:

- `RDPDISC01` is the session host
- `DBTEST01` is the backend DB/file server
- `Windows App` and `AVD` are the entry path
- `Entra ID` is the edge sign-in and MFA plane
- `AAD DS` is the backend auth plane
- `RDPNT1000/2000/3000` are the routing and permission groups
- `RDPWinPath.txt` and `GroupToServer5.txt` are critical client-side routing
  files
- direct backend UNC paths under the `RDPNT` trees matter
- `Actian Zen` is part of the runtime, but it is not the only dependency
- pure `RemoteApp` publication is configured, but pure `RDPWin RemoteApp`
  behavior is still not proven stable

# Final Conclusion

This lab works because it stopped treating `RDPWin` as a simple standalone
Windows app.

The successful shape is:

- modern edge access through `Entra ID` and `AVD`
- classic-style backend behavior through `AAD DS`
- explicit per-user backend share routing
- aligned share and `NTFS` ACLs
- `Actian Zen` plus `UNC` path access together

That is why the Azure discovery environment can now reproduce the core working
path for staged users, while still showing that pure `RemoteApp` compatibility
remains the open application question.
