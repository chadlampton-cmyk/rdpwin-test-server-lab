# Access And Routing Plan

Last updated: 2026-04-27.

## Purpose

This document defines the target access and database-routing design for the
 temporary `RDPWin` AVD lab.

It turns the current lab findings into an implementation plan that can be used
 for engineering, validation, and handoff.

This is a design and execution plan. It is not a statement that the current lab
 is production-ready or fully PCI DSS compliant.

## Problem Statement

The lab needs to support:

- Entra-authenticated user access through Windows App / AVD
- a customer-style app-first user experience
- deterministic `RDPWin` launch at logon
- deterministic full logoff when `RDPWin` closes
- separation between admin and non-admin access
- per-user database routing so users only reach their own database path

The legacy environment historically used AD security groups to drive user-to-DB
 routing. In this lab, the target identity source is Entra, so the routing
 design must no longer depend on a user manually selecting a DB path or on
 broad desktop access.

## Design Summary

The recommended target state is:

- AVD desktop remains the user path
- pure RemoteApp is not the active path
- a Scheduled Task replaces the current `HKLM\...\Run` trigger
- Entra security groups become the source of truth for routing
- a local mapping/broker on `RDPDISC01` resolves which DB a user is allowed to
  use
- users do not manually browse or choose DB paths
- `RDPWin` is launched only after the correct routing decision is made
- when `RDPWin` closes, the Windows session logs off fully
- admin access remains separate from the user path

For UNC / SMB authorization, the lab should no longer assume that a standalone
`DBTEST01` with Entra-only identities can enforce Windows share and NTFS ACLs
the same way the legacy AD environment did.

The chosen remediation path is:

- add `Microsoft Entra Domain Services` to the lab tenant
- join `DBTEST01` to the managed domain
- use domain-resolvable groups for UNC/share authorization
- keep Entra groups as the high-level routing source of truth
- translate those groups into domain-backed ACL enforcement on `DBTEST01`

## Why This Model

This model is recommended because:

- `RDPWin` works in a desktop session
- `RDPWin` does not behave reliably as pure RemoteApp
- killing or replacing `explorer.exe` destabilized the app
- the current `HKLM Run` launcher is inconsistent across users
- database routing is an authorization problem, not just a launch problem

The right control point is therefore the logon/launch broker on the session
 host, not raw desktop access and not manual DB selection by users.

For the backend file server, the right enforcement point is a domain-backed SMB
authorization model, not local groups on a standalone Windows server trying to
resolve `AzureAD\\...` principals.

## Target Access Model

### User Path

- user signs in with Entra through Windows App / AVD
- user lands on the AVD desktop for `RDPDISC01`
- a deterministic Scheduled Task runs at logon
- the logon script/broker determines the user’s allowed DB target
- the broker writes the correct `RDPWin` runtime config for that user/session
- `RDPWin` launches automatically
- when `RDPWin` exits, the session logs off

### Admin Path

- admins use a separate admin access path
- admin identities are not used to validate the customer-style session
- admin users retain a normal desktop
- admin access does not define the end-user control model

## Identity And Group Model

Use Entra groups as the routing source of truth.

Recommended group families:

- `RDPWin-Users`
  - base user access group for the AVD desktop path
- `RDPWin-Admins`
  - admin-only path
- `RDPWin-DB-<tenant-or-property>`
  - one group per allowed database target

Examples:

- `RDPWin-DB-DB01`
- `RDPWin-DB-DB02`
- `RDPWin-DB-ResortA`
- `RDPWin-DB-ResortB`

### Group Rules

- every end user must be in `RDPWin-Users`
- every end user must match exactly one DB-routing group
- admin users must not be used for customer-path validation
- if a user matches zero DB groups or multiple DB groups, launch must fail
  closed

This prevents silent misrouting and is the safest model for PCI-oriented access
 control.

## Backend Authorization Model

The backend authorization model is split into two layers:

- Entra groups determine the user's intended route
- domain-backed groups and ACLs on `DBTEST01` enforce UNC visibility

Current conclusion:

- direct SMB / NTFS ACL assignment to Entra-only cloud identities on
  `DBTEST01` failed with principal-resolution errors before AAD DS was added
- AAD DS was then deployed for `fshostedtest.onmicrosoft.com`
- `DBTEST01` was joined to the managed domain
- the first hybrid attempt kept `RDPDISC01` Entra joined while `DBTEST01` was
  AAD DS joined
- that attempt still required explicit `fshostedtest\\CSS0` SMB auth and did
  not produce seamless backend access
- the resulting architecture decision is:
  - Entra at the edge for Windows App / AVD sign-in
  - AAD DS on both Windows servers for backend auth
- `RDPWin` is now confirmed opening against the correct backend database per
  staged user in that model once the `RDPNT1000/2000/3000` share and NTFS ACLs
  are aligned on `DBTEST01`

Implemented UNC / SMB repair path:

1. Deploy `Microsoft Entra Domain Services` for the active workforce tenant.
2. Join `DBTEST01` to the managed domain.
3. Join `RDPDISC01` to the managed domain for backend app/auth consistency.
4. Create or sync the `RDPNT1000`, `RDPNT2000`, and `RDPNT3000` routing groups
   as domain-resolvable principals.
5. Apply share and NTFS ACLs on `DBTEST01` to those domain principals.
6. Retest UNC visibility with:
   - `CSS0 -> RDPNT1000`
   - `HSC1 -> RDPNT2000`
   - `TCS2 -> RDPNT3000`
7. Confirm `RDPWin` opens to the correct backend database for each staged user.

Implementation result:

- `CSS0` first proved the backend auth direction was correct
- `HSC1` then exposed that `RDPNT2000` had not been permissioned the same way
  as `RDPNT1000`
- after normalizing share and NTFS ACLs across all `RDPNT` trees on
  `DBTEST01`, `RDPWin` routed correctly per staged user

Current active tenant for this plan:

- `fullsteamhostedtest.onmicrosoft.com`
- tenant ID: `2fc43150-f428-43e0-8eac-0a547eaa5dc6`

Current AAD DS prep already completed there:

- `Microsoft.AAD` provider registered
- dedicated subnet created:
  - `aadds-centralus`
  - `10.10.10.0/24`

## Azure Assignment Model

### AVD App Group Assignment

- assign `RDPWin-Users` to the AVD desktop app group
- do not use the desktop app group as a broad catch-all for admins

### VM Login RBAC

- grant `Virtual Machine User Login` to end-user groups only
- grant `Virtual Machine Administrator Login` only to separate admin groups
- do not assign broad admin roles to customer-style test users

## Session Host Model

`RDPDISC01` remains the user-facing session host.

The session host should:

- keep `explorer.exe` alive
- suppress `Server Manager`
- avoid shell replacement
- avoid unsupported Start-menu hacks
- rely on a deterministic scheduled launch flow instead of ad hoc shell tweaks

## Launcher And Broker Design

### Trigger

Replace the current machine-wide `Run` key with a Scheduled Task:

- trigger: `AtLogOn`
- scope: non-admin user logons only
- run context: interactive user session
- action: PowerShell launcher/broker script

### Launcher Responsibilities

The launcher should:

1. identify the current user
2. verify the user is not admin
3. resolve the user’s routing identity
4. determine the allowed DB target
5. fail closed if routing is ambiguous or missing
6. write the correct `RDPWin` config for the session
7. launch `RDPWin`
8. monitor the `RDPWin` process
9. fully log off the session when `RDPWin` exits
10. write audit entries for all of the above

### Broker Responsibilities

The broker is the routing logic between identity and DB target.

It should:

- use Entra group membership as the source of truth
- map the user to one and only one DB target
- generate the runtime settings `RDPWin` needs
- prevent the user from manually selecting or browsing other DB paths

## Routing Source Options

There are two realistic ways to implement group-to-DB routing.

### Option A: Local Mapping Cache

Recommended starting point.

Pattern:

- a scheduled sync job or admin process exports Entra group membership and
  routing metadata to a local file on `RDPDISC01`
- the logon broker reads that local file
- the broker decides the user’s DB target from the cached mapping

Advantages:

- faster and more reliable at logon
- less dependency on live Graph calls during every session start
- easier to audit and troubleshoot

Recommended file format:

- JSON

Example shape:

```json
{
  "version": 1,
  "generatedUtc": "2026-04-15T20:00:00Z",
  "routes": [
    {
      "groupName": "RDPWin-DB-DB01",
      "dbKey": "DB01",
      "server": "DBTEST01",
      "configShare": "\\\\DBTEST01\\RDPCONFIG$",
      "dataShare": "\\\\DBTEST01\\RDPDATA$",
      "appsShare": "\\\\DBTEST01\\RDPAPPS$",
      "rdpwinPathFile": "C:\\ProgramData\\ResortDataProcessing\\RDPWin\\RDPWinPath.txt"
    }
  ]
}
```

### Option B: Live Graph Lookup

Pattern:

- broker queries Graph or another identity API at logon
- broker resolves current group membership live
- broker chooses DB target from live identity data

Advantages:

- no local sync step

Disadvantages:

- more moving parts at user logon
- more failure points
- harder to treat as deterministic if identity/API availability is degraded

Recommendation:

- do not start here
- use this only if the local cache model proves insufficient

## Config-Writing Model

The broker should write only the session/runtime settings needed for the user’s
 allowed DB target.

This likely includes some combination of:

- `RDPWinPath.txt`
- `GroupToServer5.txt`
- other `RDPWin` path/server mapping files
- per-user or per-session environment/config values

The broker must not expose or populate settings for databases the user is not
 authorized to access.

Current confirmed `RDPWinPath.txt` values in the lab are direct UNC targets,
not abstract placeholders:

- `\\DBTest01\RDPNT1000\RDP\RDP01 [CCS]`
- `\\DBTest01\RDPNT2000\RDP\RDP02 [HCS]`
- `\\DBTest01\RDPNT3000\RDP\RDP03 [TCS]`

Current confirmed `GroupToServer5.txt` note:

- `Must match the server drop down order in RDPWinPath5.txt`
- `CCS 0`
- `HSC 1`
- `TCS 2`

This implies the current client configuration is order-sensitive. If
`GroupToServer5.txt` or `RDPWinPath5.txt` is rebuilt or rewritten, the server
ordering must stay aligned with the UNC path list to avoid misrouting users to
the wrong logo/backend target.

That means the active routing and authorization model still depends on concrete
Windows file-server paths under the `RDPNT1000/2000/3000` folder trees on
`DBTEST01`.

## Fail-Closed Rules

The broker must fail closed in these cases:

- user is not in the base access group
- user has no matching DB-routing group
- user matches more than one DB-routing group
- required config or share path is missing
- target mapping file is missing or invalid
- `RDPWin` executable is missing

Fail-closed behavior should:

- log the reason
- present a controlled support message if possible
- log off the session

## Audit And Evidence Model

The final design must produce usable evidence for operations and PCI-oriented
 review.

Record at minimum:

- who logged on
- what routing decision was made
- what group or rule produced the routing decision
- what DB target was selected
- whether launch succeeded
- when `RDPWin` exited
- whether the session logged off successfully
- any fail-closed reason

Recommended evidence sources:

- Task Scheduler Operational log
- launcher transcript or structured log file
- Windows event log entries written by the broker
- Azure RBAC and AVD assignment exports
- local `Administrators` group membership snapshot

## Session Governance

Keep:

- full logoff on app close
- timeout and cleanup values for disconnected sessions
- short, known session cleanup behavior

Do not rely on:

- disconnected sessions lingering indefinitely
- users manually signing out as the primary cleanup mechanism

## What This Plan Explicitly Avoids

This plan does not depend on:

- pure RemoteApp
- shell replacement
- disabling only left-click Start
- users browsing backend DB paths manually
- broad desktop rights as the routing mechanism

## Implementation Phases

### Phase 1: Identity And Assignment

1. define Entra groups for user access and per-DB routing
2. assign AVD desktop access to the base user group
3. assign VM user login to the base user group
4. keep admin roles separate

### Phase 2: Scheduled Task Trigger

1. replace the `HKLM Run` trigger with a Scheduled Task
2. target non-admin interactive user sessions
3. keep the existing stable launch/logoff script logic as the base

### Phase 3: Routing Broker

1. define the routing map format
2. implement the local cache file
3. update the launcher to resolve user -> DB target
4. write only the required `RDPWin` runtime config
5. fail closed on ambiguity or missing routing

### Phase 4: Audit Logging

1. emit structured launch and routing logs
2. document task and script configuration
3. verify evidence can be collected after real user tests

### Phase 5: Validation

1. test with a dedicated non-admin user who maps to DB target A
2. test with a dedicated non-admin user who maps to DB target B
3. verify each user gets only their assigned DB target
4. verify close -> full logoff
5. verify admin user still receives normal desktop behavior

## Immediate Next Step

The next engineering step should be:

1. replace the current `HKLM Run` launcher with a Scheduled Task
2. keep the existing stable script logic
3. then add the routing-broker layer on top of that trigger

This keeps the work incremental:

- first make launch deterministic
- then make routing deterministic

## Handoff Summary

If another engineer picks this up, the main takeaway is:

- the correct target is not pure RemoteApp
- the correct target is not shell replacement
- the correct target is a deterministic desktop-session broker model
- identity and DB routing must be enforced at launch time, not left to the user
