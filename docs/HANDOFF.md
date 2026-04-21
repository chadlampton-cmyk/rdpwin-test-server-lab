# Handoff

Last updated: 2026-04-17.

## Cold-Start Instruction

Read this file first after reboot. This repo is the temporary `RDPWin` lab repo,
not the production AVD repo.

Stay in:

`/Users/chad.lampton/Documents/repo/rdpwin-test-server-lab`

## Current Lab Shape

- discovery session host:
  - Azure VM: `rdp-discovery-01`
  - Windows name: `RDPDISC01`
- backend DB/file server:
  - Azure VM: `db-test-01`
  - Windows name: `DBTEST01`
  - private IP: `10.210.10.5`
  - data root: `F:\RDPDiscovery`
- Azure control plane:
  - historical subscription: `platform-sandbox`
  - resource group: `rg-rdp-discovery-test`
  - host pool: `hp-rdp-discovery-test`
  - workspace: `ws-rdp-discovery-test`
  - RemoteApp group: `rag-rdp-discovery-test`
  - desktop group: `dag-rdp-discovery-test`
- active retargeting direction:
  - tenant: `fscaptest.onmicrosoft.com`
  - subscription: `FS Capabilities - Test External AVD`
  - subscription ID: `56bf2a01-7815-4df3-a396-b9b4d6a55362`
  - test operator UPN: `chad.lampton@fullsteamtest.onmicrosoft.com`

## Current Active Deployment

The repo is no longer only in retargeting mode.

As of 2026-04-16, the lab was deployed into FS Capabilities:

- tenant: `fscaptest.onmicrosoft.com`
- subscription: `FS Capabilities - Test External AVD`
- subscription ID: `56bf2a01-7815-4df3-a396-b9b4d6a55362`
- resource group: `externalavd-test-rg`
- VNet: `extavd-testing-centralus`
- subnet: `avd-hostpools-centralus`
- session host private IP: `10.10.0.5`
- backend private IP: `10.10.0.4`
- deployment result:
  - `23` added
  - `0` changed
  - `0` destroyed

The historical `platform-sandbox` deployment remains useful as prior lab
context, but it is no longer the active environment.

## What Is Installed And Working

- `DBTEST01` is deployed and bootstrapped.
- `DBTEST01` exposes:
  - `\\DBTEST01\RDPAPPS$`
  - `\\DBTEST01\RDPCONFIG$`
  - `\\DBTEST01\RDPDATA$`
- `RDPDISC01` can browse those three shares.
- `RDPDISC01` and `DBTEST01` both have `AADLoginForWindows` installed and
  succeeded.
- Entra VM login RBAC was previously present on both VMs for the original test
  operator in the source tenant.
- `RDPWin` is installed on `RDPDISC01`.
- `RDPWin` works from a full desktop session on `RDPDISC01`.
- The FS Capabilities rebuild completed successfully:
  - `db-test-01` exists
  - `rdp-discovery-01` exists
  - both VMs have `AADLoginForWindows` in succeeded state
  - `RDPDISC01` AVD registration extension succeeded
  - AVD workspace, host pool, and app groups were created in
    `externalavd-test-rg`

## Important AVD Findings

- AVD access was repaired on 2026-04-14.
- Root cause:
  - `RDPDISC01` was missing the `Remote Desktop Session Host` role
    (`RDS-RD-Server`)
  - AVD SxS stack installation was failing because of that
- Repair completed:
  - installed `RDS-RD-Server`
  - restarted `RDPDISC01`
- Current AVD health:
  - session host status: `Available`
  - session host update state: `Succeeded`

## Current Access Model

- admin path:
  - Bastion or equivalent direct admin path
  - use `localadmin` for maintenance/troubleshooting
- AVD / Windows App path:
  - workspace friendly name: `RDP Discovery Test Workspace`
  - current host pool preferred app group type: `Desktop`
  - the original source-tenant test user previously had:
    - `Desktop Virtualization User` on `dag-rdp-discovery-test`
    - no entitlement on `rag-rdp-discovery-test`

This means the current Entra user experience is desktop-first again, with
desktop-session shaping on the host rather than pure RemoteApp.

## Most Important Current Limitation

Pure RemoteApp is not usable for `RDPWin`, and it is no longer the active test
path.

Current observed behavior:

- selecting the pure RemoteApp reaches Windows `Welcome`
- the user profile loads successfully
- the session logs off almost immediately afterward
- enabling the enhanced RemoteApp shell runtime did not change that outcome
- a clean retest after the Zen license was reactivated still crashed
- the current desktop model now launches `RDPWin` at logon for non-admin users

Interpretation:

- Entra login is working
- AVD brokering is working
- profile load is working
- the Zen license issue was real, but it was not the root cause of the pure
  RemoteApp crash
- the remaining work is on the desktop-shaped user experience and any residual
  backend/app validation, not on proving RemoteApp

## Working Assumption

The active model is now:

- AVD desktop session for the user path
- local policy / scripted session shaping on `RDPDISC01`
- auto-launch `RDPWin` at logon
- make the session feel app-like
- log off the session when `RDPWin` closes

This is closer to the current TERM-server behavior than Bastion, and is more
realistic than forcing pure RemoteApp if `RDPWin` is not RemoteApp-clean.

## PCI Direction

The lab is now being aligned to a PCI-ready target state.

That is not the same thing as declaring PCI DSS compliance. The active design
goal is a more defensible control model built around:

- MFA-backed Entra / AVD user access
- dedicated non-admin users for the app path
- separate admin access for maintenance
- deterministic app launch at logon
- deterministic full logoff on app close
- auditable control execution

Reference plan:

- `docs/PCI_ALIGNMENT_PLAN.md`
- `docs/ACCESS_AND_ROUTING_PLAN.md`

## Current Desktop Session Behavior

`RDPDISC01` now has host-side session shaping applied:

- non-admin users enter through the AVD desktop
- `RDPWin` auto-launches at Windows logon
- when `RDPWin` exits, Windows logs off the session
- disconnected sessions are capped to clean up quickly
- administrative users keep the normal desktop experience
- `explorer.exe` remains running because killing or replacing the shell caused
  `RDPWin` instability during testing
- `Server Manager` is suppressed at logon

Current PCI-relevant gap:

- the current `HKLM\...\Run` launcher is not reliable across all Entra / AVD
  users and should not be treated as the final compliance-grade control

Applied host-side items:

- launcher script:
  - `C:\ProgramData\RDPWinLab\Start-RDPWinDesktop.ps1`
- Run key:
  - `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run\RDPWinDesktopLauncher`
- session policy values:
  - `fResetBroken = 1`
  - `MaxDisconnectionTime = 60000`

## Repo State

Repo-local automation now supports:

- pooled AVD host pool
- RemoteApp group for `RDPWin`
- desktop app group for desktop-session testing
- workspace association to both app groups
- AVD user RBAC assignment support
- VM login RBAC assignment support

Files that were updated for the new AVD model:

- `terraform/`
- `inventories/group_vars/all.yml`
- `roles/lab_tofu/tasks/main.yml`
- `README.md`
- `docs/RUNBOOK.md`
- `docs/TEST_PLAN.md`
- `docs/ARCHITECTURE.md`
- `docs/VALIDATION.md`

Files additionally updated to support FS Capabilities landing-zone reuse:

- `terraform/main.tf`
- `terraform/variables.tf`
- `terraform/locals.tf`
- `terraform/outputs.tf`
- `terraform/modules/network/`
- `terraform/modules/workspace/`
- `inventories/group_vars/all.yml`
- `inventories/group_vars/all.example.yml`

## What Was Verified Recently

- `tofu validate` passed against the FS Capabilities target
- `tofu plan` passed against the FS Capabilities target
- `tofu apply` completed successfully in FS Capabilities
- `az` confirmed:
  - `rdp-discovery-01-aadlogin` succeeded
  - `db-test-01-aadlogin` succeeded
  - `rdp-discovery-01-avd-register-*` succeeded
  - VM login RBAC was applied for the FS Capabilities Entra operator object
- Bastion SKU is still `Developer`
- AVD control plane confirmed in FS Capabilities:
  - workspace `ws-rdp-discovery-test` exists
  - desktop group `dag-rdp-discovery-test` exists
  - RemoteApp group `rag-rdp-discovery-test` exists
  - host pool `hp-rdp-discovery-test` exists
- Event logs confirmed:
  - RDS logon/profile load succeeds for the test user
  - pure RemoteApp session exits immediately after logon
  - enhanced RemoteApp shell runtime did not fix the pure RemoteApp failure
- DB-side checks confirmed:
  - `Actian Zen Cloud Server` is running on `DBTEST01`
  - `RDPWin Monitor GDS Reservations` is running
  - the temporary Zen license was directly queried and shown as `Expired` on
    `2026-04-15`
  - the Zen license was reactivated and `Btrieve Error 161` cleared
  - RemoteApp still crashes after the license fix
- UX shaping checks confirmed:
  - shell-kill and aggressive Start/taskbar restrictions destabilized `RDPWin`
  - those restrictions were rolled back
  - no supported local GPO was found for “disable left-click Start but keep
    right-click Start”
  - `HKLM\...\Run` launcher behavior is inconsistent across users:
    `AzureAD\ChadLampton` logged launcher activity, while
    another non-admin Entra test user did not

## Next Recommended Work

Do not spend time on more infrastructure build-out first.

The next meaningful work is:

1. validate the freshly deployed FS Capabilities lab
2. confirm AVD session-host health and user-path access in the new tenant
3. keep the desktop model as the primary user path
4. treat pure RemoteApp as a tested dead end unless new vendor guidance says
   otherwise
5. replace the current `HKLM Run` launcher with a more reliable logon-time
   trigger, preferably a Scheduled Task
6. keep `explorer.exe` alive and avoid shell replacement or aggressive Start
   menu lockdown
7. define Entra security groups for per-database routing and treat them as the
   routing source of truth
8. build the local routing-broker layer on `RDPDISC01` so users are assigned to
   a single DB target at launch time
9. validate the current desktop auto-launch and full-logoff flow end to end
   with a dedicated non-admin Entra user
10. continue backend/app validation on `DBTEST01` only if a new runtime error
   appears
11. document any remaining UX compromises instead of chasing unsupported shell
   behavior

## Probe Guidance

The probe remains useful for install/config drift checks, but it is not the
current blocker. The main open work is validating the stable desktop-shaped user
path and only chasing backend state again if a new runtime error appears.

Probe path on the Windows host:

`C:\Temp\Invoke-RDPWinLabProbe.ps1`

## Related Repos

- production AVD repo:
  - `/Users/chad.lampton/Documents/repo/rdp-avd-fshosted`
- SAW reference repo:
  - `/Users/chad.lampton/Documents/repo/saw-avd-fshosted`
- discovery notes:
  - `/Users/chad.lampton/Documents/rdp-soft-discovery`

## FYI: FS Capabilities User And Group Findings

As of 2026-04-17, the following test identities were created in
`fscaptest.onmicrosoft.com`:

- `CSS0@fscaptest.onmicrosoft.com`
- `HSC1@fscaptest.onmicrosoft.com`
- `TCS2@fscaptest.onmicrosoft.com`

Matching security groups were also created:

- `RDPNT1000`
- `RDPNT2000`
- `RDPNT3000`

Mapping applied:

- `CSS0` -> `RDPNT1000`
- `HSC1` -> `RDPNT2000`
- `TCS2` -> `RDPNT3000`

AVD-side access that was successfully configured:

- those groups were assigned `Desktop Virtualization User` on
  `dag-rdp-discovery-test`
- those groups were assigned `Virtual Machine User Login` on
  `rdp-discovery-01`

Updated AVD identity finding:

- direct sign-in with tenant-local users is not a hard blocker by itself
- `Guest Inviter` was sufficient to remove the `AADSTS500208` login-domain
  error for the test user
- `Guest Inviter` was not sufficient to allow MFA registration for the test
  user; the sign-in flow then failed with:
  - `You are required to register an authentication method to continue but none
    have been enabled for this account`
- `Message Center Reader` was sufficient to allow the test user to proceed with
  MFA registration
- `Global Reader` was also sufficient to allow MFA registration, but is broader
  than needed for the current test
- current tested conclusion:
  - AVD RBAC alone is not enough for the tenant-local user path in this
    external tenant
  - `Guest Inviter` improves account classification enough to clear
    `AADSTS500208`
  - `Message Center Reader` improves account classification enough to clear
    `AADSTS500208` and allow MFA registration
  - `Global Reader` is not the minimum working role discovered so far
- current minimum tested working Entra role for the external-tenant AVD user
  path is:
  - `Message Center Reader`
- caution:
  - `Message Center Reader` is a narrower workaround than `Global Reader`, but
    still likely too broad for a true PCI-style customer end-user model

Verified internal-user example created on `2026-04-20`:

- display name: `AVD Test 01`
- UPN: `avdtest01@fscaptest.onmicrosoft.com`
- creation method:
  - `Entra ID -> Users -> New user -> Create new user`
  - this was created as a tenant-local internal user, not
    `Create new external user`
- temporary password was set at creation time
- `forceChangePasswordNextSignIn = true`
- tested Microsoft Entra directory role progression:
  - no Entra role:
    - hit `AADSTS500208`
  - `Guest Inviter`:
    - cleared `AADSTS500208`
    - did not allow MFA registration
  - `Reports Reader`:
    - assigned as an intermediate test role
    - superseded by the narrower `Message Center Reader` test
    - do not treat it as the preferred result
  - `Message Center Reader`:
    - cleared `AADSTS500208`
    - allowed MFA registration
  - `Global Reader`:
    - cleared `AADSTS500208`
    - allowed MFA registration
- current Entra directory roles on the account as of `2026-04-20`:
  - `Guest Inviter`
  - `Message Center Reader`
- assigned Azure access only:
  - `Desktop Virtualization User` on
    `dag-rdp-discovery-test`
  - `Virtual Machine User Login` on `rdp-discovery-01`
- chat-generated replacement temporary password requested on `2026-04-20`:
  - `Q7m!P2x#L9v@R4s$T8n^W3k`
  - note: this value was documented for operator recall only; it was not
    confirmed as applied to the Entra account in Azure

This account should be treated as the reference AVD test user for proving that
tenant-local internal users in `fscaptest` can access AVD without
`Global Reader`.

Important architecture conclusion from `2026-04-20`:

- short-term target state:
  - named user exists in the Entra External ID tenant
  - user is required to use MFA
  - user signs into AVD with that external-tenant identity
  - user then signs into `RDPWin` separately with app credentials
- long-term target state:
  - `RDPWin` should eventually consume the Entra identity from the session and
    eliminate the separate app login
- constraint:
  - AVD SSO only gets the user into Windows; it does not by itself remove the
    `RDPWin` application login
  - removing the `RDPWin` login will require app-side support for modern Entra
    authentication such as `OIDC`, `SAML`, or equivalent custom integration

Open design concern for follow-up:

- even though `Message Center Reader` works, requiring any Entra directory role
  for a customer-style interactive AVD user is probably not the clean final
  design
- if a lower-privilege role cannot be found, reconsider whether the external
  tenant should be the long-term interactive AVD identity plane for PCI-style
  end users

Important DB authorization finding:

- `DBTEST01` already has the expected folders and shares:
  - `RDPNT1000 -> F:\RDPNT1000`
  - `RDPNT2000 -> F:\RDPNT2000`
  - `RDPNT3000 -> F:\RDPNT3000`
- current share / NTFS permissions are still broad and legacy-shaped
- attempts to assign the new Entra cloud groups or users directly to SMB / NTFS
  ACLs on `DBTEST01` failed with Windows principal-resolution errors
- exact failure pattern:
  - `No mapping between account names and security IDs was done`
  - `Principal AzureAD\\... was not found`
- this means the legacy model of `security group -> UNC path restriction` is not
  currently achievable on `DBTEST01` with these Entra-only identities in the
  current server identity state
- Azure inspection on `2026-04-20` confirmed there is no existing
  `Microsoft.AAD/domainServices` deployment behind this lab
- `DBTEST01` should therefore be treated as a standalone Windows file server
  with `AADLoginForWindows`, not a domain-backed SMB authorization target

Implication:

- AVD / Entra login and Windows file-share authorization are separate problems
- the current FS Capabilities test can support AVD-side access assignment
- it cannot enforce the legacy DB share restriction model with Entra-only
  identities alone on the current `DBTEST01`

Chosen UNC / SMB remediation path:

- stop treating Entra-only local groups on `DBTEST01` as a viable final answer
- deploy `Microsoft Entra Domain Services` for the lab tenant
- join `DBTEST01` to the managed domain
- create or sync the routing groups in the managed domain
- apply share and NTFS ACLs to domain-resolvable principals instead of
  `AzureAD\\...` identities
- retest the expected legacy mapping:
  - `CSS0 -> RDPNT1000`
  - `HSC1 -> RDPNT2000`
  - `TCS2 -> RDPNT3000`

Until that is complete:

- treat the `RDPNT1000/2000/3000` groups currently on `DBTEST01` as placeholders
- do not assume UNC visibility failures for `CSS0` are app bugs
- do not spend more time trying to force Entra-only SMB ACL resolution on the
  standalone `DBTEST01` server

## FYI: Additional RDP Q&A Design Findings

Useful design findings from the vendor Q&A that were not previously captured
explicitly:

- the current hosted RDP environment is explicitly AD-centric according to the
  vendor; AD is not a side dependency, it is the backbone of the current hosted
  model
- backend visibility and support troubleshooting currently assume admin-level
  access to the environment
- DNS and FQDN usage must be inventoried before final naming is finalized;
  preserving hostnames alone may not be sufficient if the current system relies
  on domain-qualified server names
- preserving server names is preferred by the vendor to reduce customer impact
  and avoid recreating customer-facing shortcuts where possible
- firewall and routing exports are required migration inputs; these were
  identified as key unknowns that vendor-provided config and DNS exports should
  help answer
- Liquid Web remains part of the current support and infrastructure dependency
  chain, especially for network / router details
- the environment is expected to run continuously with no normal shutdown model;
  24x7 operation is the baseline assumption
- critical operational knowledge is still concentrated in a small number of
  vendor contacts, so support/runbook information should be documented out of
  individual knowledge where possible

The same Q&A did not provide explicit port numbers in the transcript excerpt;
only that firewall, routing, and config-file details exist and should be
collected separately.
