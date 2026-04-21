# PCI Alignment Plan

Last updated: 2026-04-21.

## Purpose

This document defines the PCI-aligned target state for the temporary `RDPWin`
 discovery lab.

This is not a statement that the lab is PCI DSS compliant or certified. It is a
 control-design and implementation plan so the lab can move from ad hoc testing
 to a more defensible PCI-ready posture.

## Scope

This plan applies to:

- `RDPDISC01` as the AVD session host
- `DBTEST01` as the backend Actian Zen / file server
- Entra-authenticated user access through Windows App / AVD
- admin access for maintenance and troubleshooting

## Current Tested Direction

The currently supported user path is:

- Windows App / AVD desktop
- non-admin user session on `RDPDISC01`
- `RDPWin` auto-launch at logon
- full Windows logoff when `RDPWin` closes

Pure RemoteApp has been tested and is not the active target path for this app.

Current external-tenant identity findings:

- tenant-local named users in `fscaptest` can sign into AVD
- AVD RBAC alone is not sufficient for the tested external-tenant user path
- the current minimum tested working Entra role for MFA registration and AVD
  access is `Message Center Reader`
- `Guest Inviter` clears `AADSTS500208` but does not allow MFA registration
- `Global Reader` also works, but is broader than needed

## PCI-Relevant Design Principles

The design direction for this lab should satisfy these operational control
 themes:

- MFA on remote access into the environment
- unique user identity
- least privilege
- separation of admin and user access paths
- reliable session start and session end controls
- auditable control execution
- minimization of exposed desktop functionality without breaking the app

## Target Access Model

### User Path

- users authenticate with Entra through Windows App / AVD
- users are expected to satisfy MFA before entering the AVD session
- users are assigned only the AVD desktop app group required for the
  `RDPWin` session
- users are not granted local admin rights
- users are not granted Azure VM administrator login rights
- `RDPWin` launches automatically at user logon
- when `RDPWin` exits, the Windows session logs off fully

### Admin Path

- administrators use a separate admin path for maintenance
- admin users are kept separate from the end-user testing path
- admin users retain a normal desktop experience
- admin troubleshooting does not define the PCI user-path standard

## Current Control Gaps

1. The current `HKLM\...\Run` launcher is not reliable enough across Entra/AVD
   users.
   - It launched correctly for `AzureAD\ChadLampton`.
   - It did not run for `felix.ferdinand@fullsteamhosted.com`.
   - A control that applies to one user but not another is not strong enough to
     treat as a PCI-ready enforcement mechanism.

2. Admin and user testing have been mixed in earlier iterations.
   - `AzureAD\ChadLampton` is currently in local `Administrators` on
     `RDPDISC01`.
   - That is useful for troubleshooting, but it is not the customer-style
     access model.

3. The shell-hardening approach is not finalized.
   - Killing or replacing `explorer.exe` destabilized `RDPWin`.
   - Aggressive Start/taskbar restrictions also destabilized the app.
   - No supported local GPO was found for “disable left-click Start but keep
     right-click Start.”

4. The current enforcement logging is incomplete.
   - The launcher writes a local log file, which is useful.
   - A stronger PCI-ready path should also rely on a deterministic trigger and
     leave clearer operational evidence when it runs.

5. The current external-tenant identity model is not yet least-privilege clean.
   - The current minimum tested working role for MFA registration is
     `Message Center Reader`.
   - That is narrower than `Global Reader`, but still broader than a
     customer-style end user should ideally hold.
   - The external-tenant user model should not yet be treated as the final
     PCI-aligned identity design.

6. Backend UNC / SMB enforcement is not yet PCI-aligned.
   - `DBTEST01` is currently a standalone Windows file server with
     `AADLoginForWindows`, not a domain-backed authorization target.
   - The legacy `group -> UNC path` model cannot currently be enforced with
     Entra-only SMB / NTFS ACLs on `DBTEST01`.

## PCI-Aligned Implementation Plan

### Phase 1: Lock The Access Model

1. Use dedicated non-admin Entra users or groups for the customer-style path.
2. Keep admin users separate.
3. Keep Bastion or direct admin access as the maintenance path only.
4. Do not use admin users to validate the customer session experience.

Current note:

- if `Message Center Reader` remains required for external-tenant MFA
  registration, treat it as a temporary workaround rather than the final target
  role model

### Phase 2: Replace The Launch Trigger

Replace the current machine `Run` key trigger with a more reliable logon-time
 mechanism, preferably:

- a Scheduled Task triggered at user logon, or
- a deterministic logon script mechanism that is confirmed to run in Entra/AVD
  sessions

The trigger must:

- run for all non-admin interactive user sessions
- skip admin sessions cleanly
- launch `RDPWin`
- log off the session when `RDPWin` exits
- leave an auditable record that it ran

### Phase 3: Keep The Shell Stable

1. Keep `explorer.exe` alive unless the vendor provides a stronger supported
   requirement.
2. Suppress `Server Manager` at logon.
3. Avoid shell replacement for now.
4. Avoid unsupported Start-menu tricks as a control objective.

The goal is not a perfect kiosk shell. The goal is a stable app-first session
 with least privilege and reliable session termination.

### Phase 4: Session Governance

1. Keep non-admin sessions on enforced timeouts and cleanup values.
2. Confirm that app close results in full logoff, not disconnected session
   sprawl.
3. Validate session behavior with at least one dedicated non-admin user that is
   not in local `Administrators`.

### Phase 5: Evidence And Audit Trail

Capture and retain:

- AVD entitlement assignment model
- VM login RBAC model
- local admin membership on `RDPDISC01`
- launcher/trigger configuration
- evidence that non-admin users auto-launch `RDPWin`
- evidence that `RDPWin` close causes full logoff
- any remaining shell exposure accepted as a documented tradeoff
- evidence of the exact Entra role required to permit MFA registration for the
  external-tenant user path
- evidence of the final domain-backed UNC authorization model once implemented

### Phase 6: Backend Authorization Repair

1. Deploy `Microsoft Entra Domain Services` for the active lab tenant.
2. Join `DBTEST01` to the managed domain.
3. Recreate or sync the `RDPNT1000`, `RDPNT2000`, and `RDPNT3000` routing
   groups as domain-resolvable principals.
4. Apply share and NTFS ACLs on `DBTEST01` to those domain principals.
5. Retest:
   - `CSS0 -> RDPNT1000`
   - `HSC1 -> RDPNT2000`
   - `TCS2 -> RDPNT3000`

## What Not To Treat As PCI Requirements

The following are not good primary control objectives for this lab:

- forcing pure RemoteApp for `RDPWin`
- disabling only left-click Start while preserving right-click Start
- killing `explorer.exe` if doing so breaks the business application
- treating `Message Center Reader` as an acceptable permanent customer-user role
- treating standalone `DBTEST01` local groups as a valid final UNC control plane

Those may look cleaner cosmetically, but they are not more defensible than a
 stable, least-privileged, MFA-backed desktop session with deterministic
 launch/logoff behavior.

## Next Recommended Engineering Step

The next implementation step should be:

1. replace the `HKLM Run` launcher with a Scheduled Task at user logon
2. continue external-tenant role minimization below `Message Center Reader` if
   possible
3. keep `AzureAD\ChadLampton` as admin-only validation
4. begin planning `Microsoft Entra Domain Services` for `DBTEST01`
5. document the result in `docs/HANDOFF.md` and `docs/VALIDATION.md`

## Reference Sources

Use the official PCI SSC sources when validating or defending this design:

- PCI SSC document library:
  `https://www.pcisecuritystandards.org/document_library/`
- PCI DSS v4.0.1:
  `https://www.pcisecuritystandards.org/document_library/?category=pcidss&document=pci_dss`
- PCI SSC MFA FAQ:
  `https://www.pcisecuritystandards.org/faq/articles/Frequently_Asked_Question/In-what-circumstances-is-multi-factor-authentication-required/`
