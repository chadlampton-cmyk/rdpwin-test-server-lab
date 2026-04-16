---
title: "Resort Data Processing: AVD / Entra Target Model"
date: "April 16, 2026"
geometry: margin=1in
fontsize: 11pt
colorlinks: false
---

# Executive Summary

This document summarizes the current hosted-environment server pattern, the
target Azure Virtual Desktop direction, and the current planning model for
capacity and migration.

The intended direction is to move away from the legacy Active Directory driven
terminal-server model and toward a Microsoft Entra and Azure Virtual Desktop
model. The current discovery and lab work is focused on proving what that
future-state pattern should look like while preserving application behavior for
`RDPWin`.

# Current Hosted Environment Shape

## Expected Server Groups

- Terminal: `TERM01`, `TERM02`, `TERM03`, `TERM04`, `TERM06`
- Domain / Identity: `AD01`, `AD02`
- Database: `DB01`, `DB02`, `DB04`
- Backup / Replication: `BACKUP01`, `BACKUP02`, `BACKUP04`, `DPM01`
- Web / App: `IRM01`, `IRM02`, `IRM04`, `IRM`, `API`, `Sales`
- Test / Staging references observed: `DBTEST`, `TERMTEST`

## Current Access and Dependency Pattern

The current hosted pattern is terminal-server driven and Active Directory
integrated.

High-level flow:

`Users -> TERM servers -> AD -> DB lane -> application data`

Observed lane alignment:

- `TERM01` -> `DB01`
- `TERM03` -> `DB01`
- `TERM02` -> `DB02`
- `TERM04` -> `DB02`
- `TERM06` -> likely `DB02`

Observed web / database alignment:

- `IRM01` -> `DB01`
- `IRM02` -> `DB02`
- `IRM04` -> present, but not yet clearly in the active production pattern

This means the current estate behaves like two primary backend lanes, with the
terminal tier and parts of the web tier aligning to `DB01` or `DB02`.

# Target Direction

## Identity and Access Model

The target direction is **not** to carry classic Active Directory forward as
the primary access model. The target direction is:

- Microsoft Entra for identity
- Azure Virtual Desktop for hosted session access
- an application-aware launch and routing model for `RDPWin`

High-level future-state flow:

`Users -> Entra / AVD -> session host -> DB path selection -> DB servers`

This is different from the current model:

`Users -> TERM -> AD -> DB01 / DB02`

Because the current environment uses AD security groups and UNC/share-driven
path selection, the future-state AVD model must replace that routing behavior
with a new control mechanism. The current working design is:

- Entra groups become the routing source of truth
- the session host launches `RDPWin`
- a local broker / launcher determines the correct database lane for the user
- users do not manually browse shares or choose raw DB paths

# Current Test Build

The current test build is intentionally narrow. It is **not** a rebuild of the
full estate.

Current test pair:

- Terminal / session host: `RDPDISC01`
- Database / backend host: `DBTEST01`

What this test pair represents:

- `RDPDISC01` stands in for the terminal / session-host layer
- `DBTEST01` stands in for the backend database layer

What this test pair does **not** rebuild:

- `AD01`, `AD02`
- `BACKUP01`, `BACKUP02`, `BACKUP04`, `DPM01`
- `IRM01`, `IRM02`, `IRM04`, `IRM`, `API`, `Sales`

This is a deliberate discovery and design step, not a full production cutover.

# Capacity Planning Model

## Planning Assumption

The current working planning assumption for AVD session hosts is:

- `16 vCPU`
- `64 GB RAM`
- disk sized according to probe and application footprint

## User Density Assumption

The current working assumption is:

- approximately `40-50` users per terminal / session host

This is considered a more realistic starting point for `RDPWin` than the
claimed legacy density of approximately `300` users per terminal server.

## What That Means At 1,200 Users

If the target user population is approximately `1,200` concurrent or expected
hosted users:

- at `50 users` per session host -> `24` terminal / session hosts
- at `40 users` per session host -> `30` terminal / session hosts

Reasonable planning range:

- `24-30` AVD session hosts

This is the practical starting model for architecture and cost planning until
application-specific testing proves a different safe density.

# Recommended Conceptual Model

With a `24-30` session-host range and three database servers in the planning
discussion, the conceptual shape looks like this:

## Session Tier

- `24-30` Entra-authenticated AVD session hosts
- each host sized at approximately `16 vCPU / 64 GB RAM`
- each host targeted at approximately `40-50` users

## Database Tier

- three database servers in the planning model
- database-lane assignment handled through application-aware routing rather than
  legacy AD / UNC dependence

## Web / IRM Tier

- IRM servers remain a separate consideration
- current findings suggest IRM-to-database relationships still matter
- the web tier should be evaluated as its own dependency lane rather than
  assumed to disappear inside the AVD session-host model

High-level target shape:

`Users -> Entra / AVD -> 24-30 session hosts -> brokered DB lane -> 3 DB servers`

With related web dependencies where required:

`IRM servers -> aligned DB lane`

# Practical Conclusion

The project is currently validating what an Entra-joined AVD future state
should look like, using `RDPDISC01` and `DBTEST01` as the discovery pair.

The key design direction is:

- move to Entra
- use AVD for hosted access
- replace AD-group and UNC-share routing with a controlled session-host routing
  model
- size session hosts conservatively at first
- plan for approximately `24-30` session hosts for a `1,200` user model unless
  testing proves a different safe density

This keeps the design aligned to modern hosted access while still respecting
the real `RDPWin` and database-lane behavior discovered in the current estate.
