# RDPWin Install Probe Analysis

Last updated: 2026-04-15

## Source Data

- Raw probe exports reviewed from `/Users/chad.lampton/Documents/RDPWinLab`
- Servers covered:
  - `RDPDISC01`
  - `DBTEST01`

## Executive Summary

The probe set is useful enough to reconstruct a coarse install timeline and confirm major component changes on both servers. It is not complete enough to serve as a full application-level validation record.

What the data does show:

- `RDPDISC01` started without `RDPWin` files present under the probed `ProgramData` path.
- `RDPDISC01` could resolve and reach `DBTEST01` over SMB before install.
- `RDPDISC01` later gained Actian/Pervasive client components and `RDPWinPath.txt`.
- `DBTEST01` gained Actian/Pervasive server components, then `RDPWin` monitor services, then a live `RDPWin.exe` process.
- `DBTEST01` was listening on ports `1583` and `3351` by the final probe and had an active local `RDPWin.exe -> 1583` connection.

What the data does not show well:

- Full installed software inventory on either server.
- Actual contents of `RDPWinPath.txt` or any other config text.
- Clean post-install backend connectivity from `RDPDISC01` to `DBTEST01` in the later runs.
- Full `RDPWin` file inventory, because the probe looked under `C:\ProgramData\ResortDataProcessing\RDPWin\RDPWin5Client\RDPWin.exe` while the live DB host process was running from `C:\Program Files\ResortDataProcessing\RDPWinMSI\RDPWin.exe`.

## Data Quality Notes

The probe output has several limitations that need to be called out explicitly:

1. `installed_software` failed on every reviewed run with:
   - `The property 'DisplayName' cannot be found on this object. Verify that the property exists.`
2. `RDPDISC01` baseline share collection failed with:
   - `Illegal characters in path.`
3. Most `AdHoc` runs on both servers used stale targets:
   - `DB01`
   - `DB02`
4. Most `AdHoc` runs did not include valid `SharePaths`.
5. Config text capture was not enabled, so `10_rdpwin_config_text_optional.json` is empty across the reviewed runs.

Because of those issues, the strongest evidence comes from:

- `04_odbc_registry.csv`
- `03_services_relevant.csv`
- `08_rdpwin_file_inventory.csv`
- `11_processes_before.csv`
- `13_processes_after.csv`
- `11a_tcp_connections_before.csv`
- `13a_tcp_connections_after.csv`

## RDPDISC01 Findings

### Baseline Before Install

Primary baseline reviewed:

- `RDPDISC01/Baseline_20260413_125122`

Findings:

- Host was `WORKGROUP`, not classic domain-joined.
- OS was `Windows Server 2022 Datacenter Azure Edition`.
- `C:\ProgramData\ResortDataProcessing\RDPWin` did not exist.
- The probed `RDPWin.exe` path did not exist.
- DNS resolved `DBTEST01` successfully to `10.210.10.5`.
- Port tests to `DBTEST01`:
  - `135`: open
  - `139`: open
  - `445`: open
  - `1583`: closed
  - `3351`: closed
- TCP snapshots showed established SMB sessions from `RDPDISC01` to `10.210.10.5:445`.
- ODBC inventory showed only the default Microsoft/SQL Server drivers. No Pervasive/Actian drivers were present yet.

Interpretation:

- Before install, the discovery host had basic name resolution and SMB reachability to the DB host.
- It did not yet have the client-side Actian/Pervasive stack captured by the probe.
- It also did not show the probed `RDPWin` footprint under `ProgramData`.

### Post-Install AdHoc Runs

Reviewed runs:

- `AdHoc_20260414_104424`
- `AdHoc_20260414_104912`
- `AdHoc_20260414_105542`

Findings:

- By `10:44 AM`, `zenengine` was present as `Actian Zen Client Cache Engine` and running.
- By `10:44 AM`, ODBC inventory showed:
  - `Pervasive ODBC Interface`
  - `Pervasive ODBC Unicode Interface`
  - `Pervasive ODBC Client Interface`
- By `10:47:44 AM`, `RDPWinPath.txt` existed under:
  - `C:\ProgramData\ResortDataProcessing\RDPWin`
- The same `RDPWinPath.txt` remained visible in the later `10:55 AM` run.
- The probe still reported the configured `RDPWin.exe` path as missing.
- No `RDPWin.exe` process was captured in the reviewed discovery-host process snapshots.

Important limitation:

- These later discovery-host runs were pointed at `DB01` and `DB02`, not `DBTEST01`.
- As a result, DNS and all port tests failed in those `AdHoc` runs, but that failure reflects stale probe input more than a real backend outage.

Interpretation:

- The discovery host clearly picked up the Actian/Pervasive client layer and at least one `RDPWin` path/config artifact.
- The later network tests from `RDPDISC01` are not trustworthy evidence of discovery-to-DB health because they were run against the wrong hostnames.
- The missing `RDPWin.exe` result is likely a probe-path mismatch rather than proof that the install failed.

## DBTEST01 Findings

Reviewed runs:

- `AdHoc_20260414_144201`
- `AdHoc_20260414_144953`
- `AdHoc_20260414_145651`
- `AdHoc_20260414_152000`
- `AdHoc_20260414_152437`

### Reconstructed Install Sequence

#### 2:42 PM

- No `RDPWin` root found under the probed `ProgramData` path.
- No `RDPWin` services captured yet.
- ODBC still looked like the pre-Actian state.

#### 2:49 PM

- `zenengine` appeared as `Actian Zen Cloud Server` and was running.
- ODBC inventory now showed:
  - `Pervasive ODBC Interface`
  - `Pervasive ODBC Unicode Interface`
  - `Pervasive ODBC Client Interface`
  - `Pervasive ODBC Engine Interface`
- `demodata` ODBC data sources appeared in both 64-bit and 32-bit registry views.

Interpretation:

- By this point, the Actian/Zen server-side layer was in place and registered properly enough to expose Pervasive ODBC components and DSNs.

#### 2:56 PM

- `RDPWin` service layer appeared:
  - `RDPWin Monitor` - `Stopped`
  - `RDPWin Monitor GDS` - `Stopped`
  - `RDPWin Monitor GDS Reservations` - `Running`

Interpretation:

- This is the first clear probe evidence that `RDPWin` components had been installed on `DBTEST01`.

#### 3:20 PM

- `C:\ProgramData\ResortDataProcessing\RDPWin` now existed.
- `RDPWinPath.txt` existed under that path.

Interpretation:

- This looks like the point where the post-install config footprint became visible under `ProgramData`.

#### 3:24 PM Final Reviewed Snapshot

The final run contains the strongest DB-host evidence:

- `RDPWin Monitor GDS Reservations` was still `Running`.
- `RDPWin.exe` was actively running as:
  - `C:\Program Files\ResortDataProcessing\RDPWinMSI\RDPWin.exe`
- `RDPWin.exe` process working set was about `127 MB`.
- TCP listeners existed on:
  - `1583`
  - `3351`
- TCP snapshots showed an established local connection:
  - `RDPWin.exe` PID `2740` connected to port `1583`

Interpretation:

- `DBTEST01` ended the captured sequence with both the Actian/Zen engine and key `RDPWin` components active.
- The DB-side app stack was not just installed; it was running.
- The most important evidence here is the live `RDPWin.exe` process path under `Program Files`, which also explains why the probe kept saying the configured `ProgramData\...\RDPWin5Client\RDPWin.exe` path was missing.

## Cross-Server Conclusions

### What the Probe Proves

- `RDPDISC01` had backend SMB reachability to `DBTEST01` before install.
- `RDPDISC01` later gained Actian/Pervasive client components.
- `RDPDISC01` later gained at least one `RDPWin` config/path artifact.
- `DBTEST01` gained Actian/Pervasive server components.
- `DBTEST01` gained `RDPWin` monitor services.
- `DBTEST01` ultimately had a running `RDPWin.exe` process and local connectivity to the Zen listener on `1583`.

### What the Probe Does Not Fully Prove

- The exact contents of `RDPWin` config files.
- Whether `RDPDISC01` was launched against `DBTEST01` successfully during the later `AdHoc` runs.
- Whether UNC/share access remained correct after the final install state.
- Whether the intended `RDPWin` executable location on `RDPDISC01` matched the probe’s hard-coded path.

## Recommended Follow-Up

If a cleaner validation record is needed, rerun the probe with these corrections:

1. Use `DBTEST01` as the target host on both servers.
2. Pass explicit share paths:
   - `\\DBTEST01\RDPAPPS$`
   - `\\DBTEST01\RDPCONFIG$`
   - `\\DBTEST01\RDPDATA$`
3. Enable config text capture if the file contents are needed.
4. Update the probe to inventory both likely executable paths:
   - `C:\ProgramData\ResortDataProcessing\RDPWin\RDPWin5Client\RDPWin.exe`
   - `C:\Program Files\ResortDataProcessing\RDPWinMSI\RDPWin.exe`
5. Fix the installed software collector so the uninstall-registry inventory does not fail on mixed objects.

## Bottom Line

The probe data is good enough to support a handoff statement like this:

> `RDPDISC01` gained the expected Actian client footprint and `RDPWin` path/config artifacts, while `DBTEST01` gained the Actian server stack, `RDPWin` monitor services, and a live `RDPWin.exe` process with active Zen connectivity.

It is not good enough to claim a complete end-to-end application validation record without pairing it with operator notes or a corrected follow-up probe.
