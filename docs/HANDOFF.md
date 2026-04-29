# Handoff

Last updated: 2026-04-27.

## Cold-Start Instruction

Read this file first after reboot. This repo is the temporary `RDPWin` lab repo,
not the production AVD repo.

Stay in:

`/Users/chad.lampton/Documents/repo/rdpwin-test-server-lab`

## Current Lab Shape

- discovery session host:
  - Azure VM: `rdp-discovery-01`
  - Windows name: `RDPDISC01`
  - private IP: `10.10.0.5`
- backend DB/file server:
  - Azure VM: `db-test-01`
  - Windows name: `DBTEST01`
  - private IP: `10.10.0.4`
  - staged data roots:
    - `F:\RDPNT1000`
    - `F:\RDPNT2000`
    - `F:\RDPNT3000`
- Azure control plane:
  - historical subscription: `platform-sandbox`
  - resource group: `rg-rdp-discovery-test`
  - host pool: `hp-rdp-discovery-test`
  - workspace: `ws-rdp-discovery-test`
  - RemoteApp group: `rag-rdp-discovery-test`
  - desktop group: `dag-rdp-discovery-test`
- active live tenant:
  - tenant: `fullsteamhostedtest.onmicrosoft.com`
  - tenant ID: `2fc43150-f428-43e0-8eac-0a547eaa5dc6`
  - subscription: `FS Capabilities - Test External AVD`
  - subscription ID: `56bf2a01-7815-4df3-a396-b9b4d6a55362`
  - test operator UPN: `chad.lampton@fullsteamhosted.com`

## Current Active Deployment

The repo is no longer only in retargeting mode.

As of 2026-04-23, the lab is active in FS Capabilities after the subscription
move into the workforce tenant:

- tenant: `fullsteamhostedtest.onmicrosoft.com`
- tenant ID: `2fc43150-f428-43e0-8eac-0a547eaa5dc6`
- subscription: `FS Capabilities - Test External AVD`
- subscription ID: `56bf2a01-7815-4df3-a396-b9b4d6a55362`
- resource group: `externalavd-test-rg`
- VNet: `extavd-testing-centralus`
- subnet: `avd-hostpools-centralus`
- managed domain: `fshostedtest.onmicrosoft.com`
- session host private IP: `10.10.0.5`
- backend private IP: `10.10.0.4`
- deployment result:
  - `23` added
  - `0` changed
  - `0` destroyed

The historical `platform-sandbox` deployment remains useful as prior lab
context, but it is no longer the active environment.

The key current state is:

- the VM and AVD objects survived the tenant move
- user-facing AVD RBAC did not survive and was recreated in the workforce
  tenant
- the rejected hybrid model was:
  - Entra-joined `RDPDISC01`
  - AAD DS-joined `DBTEST01`
- the accepted working model is now:
  - Entra at the edge through Windows App / AVD
  - AAD DS on both Windows servers for backend app, SMB, and database auth
  - corrected share and NTFS ACLs across all `RDPNT1000/2000/3000` trees on
    `DBTEST01`

## What Is Installed And Working

- `DBTEST01` is deployed and bootstrapped.
- `DBTEST01` exposes the staged backend trees:
  - `\\DBTEST01\RDPNT1000`
  - `\\DBTEST01\RDPNT2000`
  - `\\DBTEST01\RDPNT3000`
- `DBTEST01` still has `AADLoginForWindows` installed and succeeded.
- `RDPDISC01` originally had `AADLoginForWindows` installed and succeeded, was
  rebuilt from the preserved OS disk after the stuck extension delete, and was
  then moved onto the managed-domain backend model.
- Entra VM login RBAC was previously present on both VMs for the original test
  operator in the source tenant.
- `RDPWin` is installed on `RDPDISC01`.
- `RDPWin` opens from the desktop session on `RDPDISC01`.
- `RDPWin` now resolves and opens the correct backend database per staged user
  after the `RDPNT1000/2000/3000` share and NTFS permissions were corrected on
  `DBTEST01`.
- The FS Capabilities rebuild completed successfully:
  - `db-test-01` exists
  - `rdp-discovery-01` exists
  - both VMs originally had `AADLoginForWindows` in succeeded state after the
    FS Capabilities rebuild
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
  - current host pool preferred app group type: `RailApplications`
  - `RDPWin` is published from:
    `C:\Program Files\ResortDataProcessing\RDPWinMSI\RDPWin.exe`
  - `CSS0@fullsteamhostedtest.onmicrosoft.com` was assigned
    `Desktop Virtualization User` on `rag-rdp-discovery-test`
  - printer redirection is enabled on the host pool with
    `redirectprinters:i:1`

This means the current declared AVD user path is `RemoteApp`, while older
desktop-first shaping tests remain historical context only.

Current routing model:

- `CSS0 -> RDPNT1000`
- `HSC1 -> RDPNT2000`
- `TCS2 -> RDPNT3000`

## Most Important Current Limitation

The current limitation is no longer AVD publication or session-host health.

Current known-good platform state:

- Entra login is working
- AVD brokering is working
- `RDPDISC01` is healthy and available in the host pool
- `RDPWin` is published as a `RemoteApp`
- printer redirection is enabled

Historical note worth keeping:

- earlier pure-RemoteApp attempts crashed after profile load
- the Zen license issue was real, but it was not the root cause of that older
  failure path

Use that crash history as background, not as the default description of the
current lab state without a fresh reproduction.

## Working Assumption

The active model is now:

- `Windows App` / `AVD` for user entry
- published `RemoteApp` for `RDPWin`
- `AAD DS` on both Windows servers for backend app, `SMB`, and database auth
- staged user routing through `RDPNT1000/2000/3000`

Earlier desktop-session shaping remains available as historical lab context, but
it should not be treated as the current declared user path.

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
  - `AADLoginForWindows` succeeded on both VMs after the initial FS
    Capabilities rebuild
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
  - the old post-license RemoteApp crash result should be treated as historical
    context unless reproduced again in the current setup
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
3. keep the published `RemoteApp` path and backend dependency chain aligned with
   the live test state
4. keep desktop-shaping guidance as fallback/recovery context, not as the
   default target narrative
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
current blocker. The main open work is validating the active RemoteApp path and
only chasing backend state again if a new runtime error appears.

Probe path on the Windows host:

`C:\Temp\Invoke-RDPWinLabProbe.ps1`

## Related Repos

- production AVD repo:
  - `/Users/chad.lampton/Documents/repo/rdp-avd-fshosted`
- SAW reference repo:
  - `/Users/chad.lampton/Documents/repo/saw-avd-fshosted`
- discovery notes:
  - `/Users/chad.lampton/Documents/rdp-soft-discovery`

## FYI: Tenant Pivot And Current User And Group Findings

The active lab subscription was later moved by Fullsteam billing/governance
from the old external-tenant context into the workforce tenant:

- `fullsteamhostedtest.onmicrosoft.com`
- tenant ID: `2fc43150-f428-43e0-8eac-0a547eaa5dc6`

The subscription ID remained:

- `56bf2a01-7815-4df3-a396-b9b4d6a55362`

The following workload objects were confirmed still present after the move:

- `db-test-01` / `DBTEST01`
- `rdp-discovery-01` / `RDPDISC01`
- host pool: `hp-rdp-discovery-test`
- desktop app group: `dag-rdp-discovery-test`
- remote app group: `rag-rdp-discovery-test`
- workspace: `ws-rdp-discovery-test`

Current active test identities were recreated in
`fullsteamhostedtest.onmicrosoft.com` on `2026-04-23`:

- `CSS0@fullsteamhostedtest.onmicrosoft.com`
- `HSC1@fullsteamhostedtest.onmicrosoft.com`
- `TCS2@fullsteamhostedtest.onmicrosoft.com`

Creation-time temporary passwords are no longer authoritative.

- all three staged users had password resets and follow-up sign-ins during the
  AAD DS validation work
- do not assume the original creation-time temporary passwords are still valid
- if a user path must be retested from scratch, reset the user in Entra ID and
  record the new password outside git

Matching Entra cloud groups were recreated:

- `RDPNT1000`
- `RDPNT2000`
- `RDPNT3000`

Mapping applied:

- `CSS0` -> `RDPNT1000`
- `HSC1` -> `RDPNT2000`
- `TCS2` -> `RDPNT3000`

AVD-side access that is currently configured in the new workforce tenant:

- those groups were assigned `Desktop Virtualization User` on
  `dag-rdp-discovery-test`
- those groups were assigned `Virtual Machine User Login` on
  `rdp-discovery-01`

RBAC recheck after the subscription move showed:

- the VMs and AVD control-plane objects survived
- the user-facing RBAC at the VM/app-group scopes did not
- the above AVD RBAC had to be recreated in the new workforce tenant

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

Current workforce-tenant staged users created on `2026-04-23`:

- `CSS0@fullsteamhostedtest.onmicrosoft.com`
- `HSC1@fullsteamhostedtest.onmicrosoft.com`
- `TCS2@fullsteamhostedtest.onmicrosoft.com`
- all three were created as tenant-local users with
  `forceChangePasswordNextSignIn = true`, but those original temporary
  passwords should now be treated as stale
- current staged Entra cloud groups:
  - `RDPNT1000`
  - `RDPNT2000`
  - `RDPNT3000`
- current mapping:
  - `CSS0 -> RDPNT1000`
  - `HSC1 -> RDPNT2000`
  - `TCS2 -> RDPNT3000`
- current Azure access:
  - `Desktop Virtualization User` on `dag-rdp-discovery-test` for all three
    groups
  - `Virtual Machine User Login` on `rdp-discovery-01` for all three groups

Important architecture conclusion from `2026-04-23`:

- short-term target state:
  - named user exists in the workforce tenant
  - user is required to use MFA
  - user signs into AVD with that workforce-tenant identity
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

- even though the tenant move removed the old external-tenant role workaround,
  the UNC / SMB model is still blocked until `DBTEST01` is domain-joined
- if `Microsoft Entra Domain Services` cannot be deployed, reconsider whether
  the current Windows file-server model is the right backend target for
  `RDPWin`
  tenant should be the long-term interactive AVD identity plane for PCI-style
  end users

Important DB authorization finding confirmed again after the workforce-tenant
pivot:

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
- live translation test on `DBTEST01` in the new workforce tenant on
  `2026-04-23` also failed for:
  - `AzureAD\\RDPNT1000`
  - `AzureAD\\RDPNT2000`
  - `AzureAD\\RDPNT3000`
  - `fullsteamhostedtest\\RDPNT1000`
  - `fullsteamhostedtest\\RDPNT2000`
  - `fullsteamhostedtest\\RDPNT3000`
- exact failure remained:
  - `Some or all identity references could not be translated`
- `DBTEST01` should therefore be treated as a standalone Windows file server
  with `AADLoginForWindows`, not a domain-backed SMB authorization target
- confirmed `RDPWinPath.txt` backend targets are the logo-specific UNC paths:
  - `\\DBTest01\RDPNT1000\RDP\RDP01 [CSS]`
  - `\\DBTest01\RDPNT2000\RDP\RDP02 [HCS]`
  - `\\DBTest01\RDPNT3000\RDP\RDP03 [TCS]`
- confirmed `GroupToServer5.txt` ordering note:
  - `Must match the server drop down order in RDPWinPath5.txt`
  - `CCS 0`
  - `HSC 1`
  - `TCS 2`
- this confirms the current `RDPWin` client pathing model depends on direct UNC
  paths under the `RDPNT1000/2000/3000` trees, not just the hidden
  `RDPAPPS$ / RDPCONFIG$ / RDPDATA$` shares
- this also confirms the client-side routing config is order-sensitive and not
  just path-sensitive; any rebuild of the `RDPWin` config files must preserve
  both the path list and the server-order index mapping

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
- retest the concrete `RDPWinPath.txt` targets:
  - `CSS0 -> \\DBTest01\RDPNT1000\RDP\RDP01 [CCS]`
  - `HSC1 -> \\DBTest01\RDPNT2000\RDP\RDP02 [HCS]`
  - `TCS2 -> \\DBTest01\RDPNT3000\RDP\RDP03 [TCS]`

Until that is complete:

- treat the `RDPNT1000/2000/3000` groups currently on `DBTEST01` as placeholders
- do not assume UNC visibility failures for `CSS0` are app bugs
- do not spend more time trying to force Entra-only SMB ACL resolution on the
  standalone `DBTEST01` server

Latest AAD DS prep completed in `fullsteamhostedtest.onmicrosoft.com`:

- `Microsoft.AAD` resource provider registered
- dedicated subnet created:
  - VNet: `extavd-testing-centralus`
  - subnet: `aadds-centralus`
  - prefix: `10.10.10.0/24`
- selected managed domain deployment values:
  - name: `fshostedtest.onmicrosoft.com`
  - subscription: `FS Capabilities - Test External AVD`
  - resource group: `externalavd-test-rg`
  - region: `Central US`
  - SKU: `Standard`
  - network:
    - virtual network: `extavd-testing-centralus`
    - subnet: `aadds-centralus`
    - subnet address: `10.10.10.0/24`
    - network security group: `aadds-nsg`
  - administrator group:
    - group: `AAD DC Administrators`
    - membership type: `Assigned`
  - notifications:
    - notify global administrators: `Yes`
    - notify `AAD DC Administrators`: `Yes`
  - synchronization:
    - scope: `All`
    - filter: `No`
  - security settings:
    - TLS 1.2 only mode: `Enable`
    - NTLM v1 authentication: `Disable`
    - password synchronization from on-premises: `Disable`
    - NTLM password synchronization: `Enable`
    - Kerberos RC4 encryption: `Enable`
    - Kerberos armoring: `Disable`
    - LDAP signing: `Enable`
    - LDAP channel binding: `Enable`
  - tags:
    - `Environment = Test`
    - `Application = RDPWin`
    - `workload = EntraDomainServices`
    - `Owner = FSTest`
    - `Purpose = UNC-SMB-ACL-Lab`

Current AAD DS state:

- `Microsoft Entra Domain Services` now exists in `externalavd-test-rg`
- managed domain name: `fshostedtest.onmicrosoft.com`
- latest Azure verification on `2026-04-24` showed:
  - resource type: `Microsoft.AAD/DomainServices`
  - provisioning state: `Succeeded`
  - location: `centralus`

Current `RDPDISC01` repair state:

- `RDPDISC01` was proven to have mixed state after the tenant move:
  - `IMDS` returned the new workforce tenant
  - `dsregcmd` kept showing the old tenant
- the old tenant was then found in local Windows state under:
  - `HKLM\\SOFTWARE\\Microsoft\\RDInfraAgent`
  - `HKLM\\SOFTWARE\\Microsoft\\RDInfraAgent\\SxsStack`
  - `HKLM\\SYSTEM\\CurrentControlSet\\Control\\CloudDomainJoin`
- those old-tenant values were backed up and removed locally on `RDPDISC01`
- the first `AADLoginForWindows` uninstall became stuck in `Deleting` even
  after reboot, guest-agent restart, and `az vm reapply`
- the local plugin payload was already gone while Azure still held the
  extension object in `Deleting`, indicating a stuck Azure VM extension state
- recovery path used on `2026-04-24`:
  - delete only the VM resource
  - keep and reuse the existing OS disk and NIC
  - recreate `rdp-discovery-01`
  - reinstall `AADLoginForWindows`
- intermediate recovered join state before the final model change:
  - `AzureAdJoined : YES`
  - `EnterpriseJoined : NO`
  - `DomainJoined : NO`
  - `DeviceAuthStatus : SUCCESS`
- current VM extension/agent state:
  - `AADLoginForWindows: Succeeded`
  - guest agent: `Ready`
- VM login authorization gap found during retest:
  - `CSS0` was correctly in `RDPNT1000`
  - `RDPNT1000` still had `Desktop Virtualization User` on
    `dag-rdp-discovery-test`
  - `RDPNT1000` was missing `Virtual Machine User Login` on
    `rdp-discovery-01`
- fix applied:
  - `Virtual Machine User Login` was reassigned to `RDPNT1000` on
    `rdp-discovery-01`
- intermediate validation result before the final model change:
  - Windows App sign-in succeeded with
    `CSS0@fullsteamhostedtest.onmicrosoft.com`

Current backend follow-up after `DBTEST01` domain join:

- `DBTEST01` is now joined to `fshostedtest.onmicrosoft.com`
- the live file-server checks now show:
  - share `RDPNT1000` grants `FSHOSTEDTEST\\RDPNT1000`
  - NTFS on `F:\\RDPNT1000` and `F:\\RDPNT1000\\RDP` grants
    `FSHOSTEDTEST\\RDPNT1000`
  - the live backend folder for `CSS0` is `F:\\RDPNT1000\\RDP\\RDP01`
- when `CSS0` tries to access the UNC path from the Entra-joined
  `RDPDISC01` session, Windows prompts for credentials to `DBTEST01`
- entering `fshostedtest\\CSS0` works
- this proves:
  - the file path exists
  - the ACL path is present
  - the remaining gap is seamless SMB authentication / SSO between the
    Entra-joined session host and the AAD DS-joined file server

Final architecture decision and current confirmed result:

- VNet DNS on `extavd-testing-centralus` was changed to the AAD DS controller
  IPs:
  - `10.10.10.5`
  - `10.10.10.4`
- after that change, `RDPDISC01` could locate the managed-domain controllers,
  but the live `CSS0` session still showed:
  - `Cloud Kerberos enabled by policy: 0`
  - no cached tickets
  - no silent SMB access to `\\DBTEST01\RDPNT1000`
- explicit `net use \\DBTEST01\RDPNT1000 /user:fshostedtest\\CSS0 *` worked,
  which proved the user, password, share, and ACL path were valid
- `RDPDISC01` was then moved onto the managed-domain backend model so both
  Windows servers share the same AAD DS auth plane for the app path
- current target architecture is:
  - Entra ID at the edge for Windows App / AVD sign-in
  - Microsoft Entra Domain Services on both Windows servers for backend app,
    SMB, and database auth
- current confirmed outcome:
  - the original `CSS0` success was not enough by itself; `HSC1` later proved
    that only `RDPNT1000` had been permissioned correctly at first
  - share and NTFS permissions on `DBTEST01` were then corrected across all
    `RDPNT1000/2000/3000` folder trees
  - `RDPWin` now resolves and opens the correct backend database per staged
    user under the AAD DS backend model

Current handoff-ready operator summary:

- use Windows App / AVD for user entry with Entra credentials
- treat `RDPDISC01` and `DBTEST01` as the AAD DS-backed app path
- do not re-open the earlier Entra-joined hybrid experiment unless the goal is
  to re-test the rejected design
- if a user routes to the wrong DB or gets `Access is denied`, compare that
  user's `RDPNT` share and NTFS ACLs on `DBTEST01` against the known-good tree
  rather than assuming the routing files are wrong

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

## FYI: Identity And PCI Discussion Follow-Up

Additional meeting notes from the later identity / PCI discussion that should
stay attached to the lab record:

- the group wants to avoid a large identity redesign unless the app or PCI
  position forces it
- the front-end `RDPWin` access question should be separated from broader
  identity questions for adjacent systems
- the main narrow decision question is whether the hosted app front end can be
  presented through a tightly controlled `RemoteApp` / virtual desktop pattern
  without requiring every user to have a uniquely named Windows session
- the shared-account / machine-account style access model is still being
  explored for PCI acceptability if strong edge MFA, limited host rights, and
  app-level controls can be shown
- named-user access must remain a live fallback option in case the shared
  session model is rejected later

Most important technical unknowns called out in that discussion:

- confirm the real database access pattern for the app
- confirm whether the app truly requires mounted `SMB` / file-share access or
  whether `Actian Zen` connectivity is sufficient for the front-end runtime
- confirm what the internal `RDPWin` auth system actually uses for user
  identity, account storage, and MFA state
- confirm whether any shared or internal app accounts touch PCI-relevant
  functions such as uploads or writes into the card-data environment

Current practical ownership from that meeting:

- continue lab testing and rebuild work on the `RDPWin` path
- develop a future-state proposal for the `IRM` side separately
- continue compliance review of the shared-session / edge-MFA model with PCI
  stakeholders
- keep the named-user model available as a fallback if the lower-change option
  fails
