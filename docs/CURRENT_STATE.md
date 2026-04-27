# Current State

## Purpose

This note translates the current-state Miro diagrams and discovery notes into a
plain-English model for this repo.

Use it when the team needs to answer a simple question:

What does the current Resort Data Processing environment actually look like, and
why does this lab include both a terminal host and a backend server?

## Plain-English Model

The current environment is not a single-box app.

It is a multi-tier system with at least these distinct concerns:

- terminal-host access for merchant and support users
- backend database and shared-file access for `RDPWin`
- separate IRM/web/API systems beside the terminal path
- AD-based access control and machine-login behavior
- external integrations, payment-adjacent services, backup, monitoring, and VPN

The lab in this repo only recreates the narrow slice needed for discovery:

- one fresh session host: `RDPDISC01`
- one fresh backend/file server: `DBTEST01`

That is intentional. The lab is meant to prove the minimum working shape for
`RDPWin`, not to clone the entire retained environment.

## Main Tiers

### User Access Tier

Merchant and front-desk users reach `RDPWin` through a terminal-server style
experience. Discovery and the Miro diagrams both point to an app-like published
session for merchants, with a separate full-desktop workflow for support users.

In the retained environment, this access tier is built around legacy TERM/RDS
servers. In the Azure lab, `RDPDISC01` is the replacement discovery host for
that role.

### Database And File Tier

The retained environment is split across `DB01` and `DB02`, both of which are
described as Windows + Actian Zen database servers with file-share
responsibilities.

Current discovery says:

- `TERM01` and `TERM03` align to `DB01`
- `TERM02`, `TERM04`, and likely `TERM06` align to `DB02`
- UNC/share access is part of the application path
- Actian Zen is part of the database path

In the Azure lab, `DBTEST01` exists to stand in for that backend role without
rebuilding `DB01` or `DB02`.

### Identity And Authentication

The current-state diagrams show two different identity layers:

- machine users
- natural users

The plain-English meaning is:

- a user first needs Windows/server access
- once inside the terminal environment, the user then signs into `RDPWin`

The current evidence says those are not the same identity step.

Discovery points to:

- machine or session-host access being tied to classic AD/domain behavior
- application login being tied to user data in the database tier
- AD group membership influencing initial DB/share/path selection

That is why Entra-ready VM access alone does not close the migration question.
It solves VM sign-in readiness, but it does not by itself prove the full
application-routing model.

### Adjacent Systems

The current-state diagrams also show that `RDPWin` is not isolated. It sits near
other systems and integrations, including:

- IRM/web portals
- booking and reservation services
- payment-adjacent authorization systems
- VPN/customer access paths
- backup, replication, and monitoring systems

This repo does not attempt to recreate those systems. They matter as context,
but they are outside the boundary of this discovery lab.

## Why The Lab Has A Term Server And A DB Server

The Miro diagrams make the test shape easier to justify.

A terminal host alone would be too shallow because it would not prove:

- backend share reachability
- backend folder/share layout expectations
- whether `RDPWin` depends on Zen/database-side assets
- whether a fresh app host can reach the paths it expects

A database server alone would also be too shallow because it would not prove:

- how a user reaches the app
- what client-side prerequisites are needed
- whether a fresh Windows host can install and launch `RDPWin`

So this repo uses the middle ground:

- `RDPDISC01` for the access/client side
- `DBTEST01` for the backend/share side

That gives the team a controlled way to answer the practical discovery
questions without cloning the whole legacy environment.

## What The Lab Already Proves

As of 2026-04-27, the lab has validated the current working app model:

- `RDPDISC01` and `DBTEST01` both exist in Azure
- Windows App / AVD remains the Entra entry point for the staged users
- the backend app path uses `Microsoft Entra Domain Services`
- `DBTEST01` hosts the staged backend trees:
  - `F:\RDPNT1000`
  - `F:\RDPNT2000`
  - `F:\RDPNT3000`
- per-user routing is staged as:
  - `CSS0 -> RDPNT1000`
  - `HSC1 -> RDPNT2000`
  - `TCS2 -> RDPNT3000`
- `RDPWin` now resolves and opens the correct backend database per staged user

That means one important legacy assumption is already reproduced in the lab:
the session host can reach backend UNC paths on the backend server.

## What Is Still Unproven

This lab does not yet prove that the retained production design has been fully
recreated.

The biggest remaining unknowns are:

- exact Actian client/server requirements
- exact `RDPWin` install sequence on a fresh host
- exact post-install config files or registry settings
- exact component that maps AD group membership to initial DB/share/path inside
  the vendor app stack
- which adjacent integrations matter for first successful launch

## How To Use This Note

Use this file together with:

- [README.md](../README.md)
- [ARCHITECTURE.md](./ARCHITECTURE.md)
- [TEST_PLAN.md](./TEST_PLAN.md)
- [HANDOFF.md](./HANDOFF.md)

The short version is:

- the current world is multi-tier
- `RDPWin` is not just one installer on one host
- the Azure lab deliberately isolates the smallest useful part of that system
- that is why this repo includes both `RDPDISC01` and `DBTEST01`
