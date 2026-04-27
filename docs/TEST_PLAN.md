# RDPWin Test Plan

Last updated: 2026-04-27.

## Goal

Prove the smallest repeatable build needed for `RDPWin` on a fresh Windows host
with an Azure-hosted backend, then shape the user session so it behaves like the
current TERM-server experience.

Use `DBTEST01` as the temporary Azure backend rather than rebuilding retained
`DB01` or `DB02`.

## Current Test Result Summary

Already proven:

- `RDPDISC01` can reach `DBTEST01` over the required UNC/share paths
- `RDPWin` is installed on `RDPDISC01`
- `RDPWin` works from a full desktop session
- AVD access to `RDPDISC01` now works through Windows App
- the temporary Zen license on `DBTEST01` was reactivated and
  `Btrieve Error 161` cleared

Not yet proven:

- whether the desktop-shaped session model is stable enough without extra shell
  lockdown
- whether any remaining backend/app issue appears after the license fix under
  normal desktop-session usage

Current evidence says pure RemoteApp is not viable for this app, and the active
test direction is now the desktop-session-shaped model.

Current PCI-alignment direction says that model should use:

- non-admin Entra users only for the user path
- separate admin identities for maintenance
- a deterministic logon trigger, not the current unreliable `HKLM Run` method

Current active workforce-tenant identity findings:

- the active lab subscription and servers are now in
  `fullsteamhostedtest.onmicrosoft.com`
- recreated users:
  - `CSS0@fullsteamhostedtest.onmicrosoft.com`
  - `HSC1@fullsteamhostedtest.onmicrosoft.com`
  - `TCS2@fullsteamhostedtest.onmicrosoft.com`
- recreated Entra cloud groups:
  - `RDPNT1000`
  - `RDPNT2000`
  - `RDPNT3000`
- recreated AVD RBAC:
  - `Desktop Virtualization User` on `dag-rdp-discovery-test`
  - `Virtual Machine User Login` on `rdp-discovery-01`

Current backend authorization findings:

- `DBTEST01` does not currently have `Microsoft Entra Domain Services`
- the local `RDPNT1000/2000/3000` groups on `DBTEST01` should be treated as
  placeholders
- the current standalone `DBTEST01` cannot reliably enforce the legacy
  `group -> UNC path` model with Entra-only SMB / NTFS ACLs
- the same principal-resolution failure was reproduced after the tenant move
  using:
  - `AzureAD\\RDPNT1000/2000/3000`
  - `fullsteamhostedtest\\RDPNT1000/2000/3000`

## Test Sequence

### 1. Backend Baseline

Before changing user-session behavior, confirm the backend assumptions still
hold:

- `DBTEST01` is running
- `RDPDISC01` can reach:
  - `\\DBTEST01\RDPNT1000`
  - `\\DBTEST01\RDPNT2000`
  - `\\DBTEST01\RDPNT3000`

Important note:

- raw share reachability from `RDPDISC01` is no longer enough to prove that the
  final user authorization model works
- user-specific UNC authorization is blocked until a domain-backed SMB identity
  source exists for `DBTEST01`

Run the probe as needed from the Windows host:

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File C:\Temp\Invoke-RDPWinLabProbe.ps1 -Phase Baseline -TargetHosts DBTEST01 -SharePaths '\\DBTEST01\RDPNT1000','\\DBTEST01\RDPNT2000','\\DBTEST01\RDPNT3000'
```

### 2. Desktop Session Validation

Use Windows App to enter the AVD desktop session on `RDPDISC01`.

Confirm:

- Windows sign-in succeeds
- MFA registration succeeds for the tested external-tenant user
- `RDPWin` launches automatically or manually from the desktop session
- app-side sign-in behavior is captured
- any backend error text is recorded precisely

Current preferred identity test user:

- `CSS0@fullsteamhostedtest.onmicrosoft.com`
- group assignment:
  - `RDPNT1000`

### 3. App-Session Shaping

Target the current-like user experience:

- user signs into Windows App
- the session lands on `RDPDISC01`
- `RDPWin` opens automatically
- the user interacts with `RDPWin`, not the desktop
- closing `RDPWin` logs off the session

This phase now uses local policy, registry, and scripted logon/session behavior
on `RDPDISC01`.

Guardrails from current testing:

- keep `explorer.exe` alive
- do not pursue shell replacement yet
- do not pursue aggressive Start/taskbar restrictions first
- `Server Manager` suppression and logoff-on-close are acceptable
- left-click-only Start suppression does not have a clean supported local GPO
- do not treat the current `HKLM Run` launcher as good enough for the final
  PCI-aligned control model

### 4. Validate Session End Behavior

Confirm whether closing `RDPWin`:

- logs off the session immediately
- disconnects the session
- or leaves the desktop available

If the default behavior is wrong, tune it with session policy rather than
returning to pure RemoteApp first.

### 5. Backend Validation After Desktop Launch

After `RDPWin` launches from the desktop session, validate the backend state on
`DBTEST01`.

Current known backend findings:

- `Actian Zen Cloud Server` is running
- `RDPWin Monitor GDS Reservations` is running
- the Zen temporary license was confirmed expired, then reactivated
- `Btrieve Error 161` is no longer the active blocker
- pure RemoteApp still fails even after the license fix
- UNC visibility tied to `RDPNT1000/2000/3000` is not yet a valid end-user
  authorization test on the current standalone `DBTEST01`

This means the main design decision is settled: keep the desktop model and stop
treating RemoteApp as the target path.

The next control-design decision is also settled: replace the current launch
trigger with a more reliable logon-time mechanism before calling this session
model ready for broader rollout.

The next backend authorization decision is also settled:

- stop trying to force Entra-only SMB / NTFS ACL resolution on the standalone
  `DBTEST01`
- move toward `Microsoft Entra Domain Services` for UNC/share enforcement
- current prep completed:
  - `Microsoft.AAD` provider registered
  - dedicated subnet created:
    - `aadds-centralus`
    - `10.10.10.0/24`
- current live work item:
  - AAD DS now shows `Succeeded` in Azure for
    `fshostedtest.onmicrosoft.com`
  - `RDPDISC01` old-tenant local join state was removed
  - `RDPDISC01` was rebuilt from the preserved OS disk after the
    `AADLoginForWindows` delete became stuck
  - `AADLoginForWindows` now shows `Succeeded`
  - Windows App login now works for
    `CSS0@fullsteamhostedtest.onmicrosoft.com`
  - `DBTEST01` is now domain-joined to `fshostedtest.onmicrosoft.com`
  - the original Entra-joined `RDPDISC01` plus AAD DS-joined `DBTEST01`
    experiment still required explicit `fshostedtest\\CSS0` auth
  - `Cloud Kerberos enabled by policy: 0` was observed in the live `CSS0`
    session
  - VNet DNS was changed to the AAD DS controllers:
    - `10.10.10.5`
    - `10.10.10.4`
  - final working direction is now:
    - Entra at the edge through Windows App / AVD
    - AAD DS on both Windows servers for backend auth
  - `RDPDISC01` was moved off the Entra-joined host path and onto the
    managed-domain backend model
  - `RDPWin` opened successfully for `CSS0`
  - `HSC1` then exposed incomplete permissions on `RDPNT2000`, which proved
    the remaining problem was per-tree ACL drift on `DBTEST01`, not routing
    config
  - share and NTFS permissions were corrected across all
    `RDPNT1000/2000/3000` trees
  - `RDPWin` now resolves and opens the correct backend database per staged
    user

## Evidence To Keep

Keep outside git unless scrubbed:

- screenshots
- Windows App behavior notes
- exact `RDPWin` login error text
- installer filenames/checksums
- probe output
- any local policy or registry changes made during session-shaping tests

Suggested local-only workspace:

```text
local/
```

## Success Criteria

- `RDPWin` works against the Azure-side backend on `RDPDISC01`
- the user path is entered through Windows App / AVD
- the user experience behaves like an app-first term-server session
- the desktop remains technically present but is no longer the practical user
  surface
- session end behavior after closing `RDPWin` is known and documented
- the resulting configuration is scriptable for future scale-out
- the `RDPNT1000/2000/3000` share and NTFS ACLs on `DBTEST01` are kept aligned
  with the staged-user routing model
- the target identity model is documented as:
  - External ID + MFA for AVD session sign-in now
  - separate `RDPWin` login in the short term
  - eventual app-side Entra authentication as a future state
