---
title: "RDPWin Probe Analysis"
subtitle: "Install and Migration Handoff Summary"
date: "April 15, 2026"
toc: true
toc-depth: 2
numbersections: true
geometry: margin=1in
fontsize: 11pt
linestretch: 1.15
header-includes:
  - \usepackage{xcolor}
  - \usepackage{fancyhdr}
  - \definecolor{headingblue}{HTML}{1F4E79}
  - \pagestyle{fancy}
  - \fancyhf{}
  - \fancyhead[L]{RDPWin Probe Analysis}
  - \fancyhead[R]{April 15, 2026}
  - \fancyfoot[C]{\thepage}
---

\thispagestyle{empty}

# Purpose

This document summarizes what the RDPWin install probe data demonstrates for the two test servers used during the April 14, 2026 install work:

- `RDPDISC01`
- `DBTEST01`

The intent is to provide a concise, migration-relevant view of what changed, what is confirmed, and where the captured data is incomplete.

# Executive Summary

The probe set is strong enough to confirm the broad shape of the install and runtime state:

- `RDPDISC01` moved from a pre-install state to a client-ready state with Actian/Pervasive components present and `RDPWin` path/config artifacts written.
- `DBTEST01` moved from a pre-install state to an active server-side state with Actian Zen running, `RDPWin` monitor services installed, and a live `RDPWin.exe` process captured.
- `DBTEST01` was listening on the expected backend ports `1583` and `3351` in the final reviewed probe.
- The strongest runtime evidence is on `DBTEST01`, where the final probe captured a running `RDPWin.exe` process and an active connection to the Zen listener on port `1583`.

The probe set is not strong enough to serve as a complete application validation package by itself because:

- installed-software collection failed on all reviewed runs
- config text capture was not enabled
- several later runs used stale target names (`DB01` and `DB02`) instead of `DBTEST01`
- the probe’s expected `RDPWin.exe` path does not match the live executable path observed on `DBTEST01`

# Scope and Limitations

## What This Analysis Covers

- baseline and ad hoc probe output reviewed for `RDPDISC01`
- ad hoc probe output reviewed for `DBTEST01`
- service, ODBC, process, TCP, DNS, and file-inventory collectors

## What This Analysis Does Not Claim

- a complete end-to-end user validation record
- authoritative contents of `RDPWin` config files
- a final production-ready migration signoff by itself

## Important Probe Gaps

1. The installed software collector failed on every reviewed run with a `DisplayName` property error.
2. Config text capture was not enabled, so config-content files are empty.
3. Discovery-host post-install connectivity runs were executed with stale hostnames, which limits the value of those later DNS and port tests.
4. The probe searched for `RDPWin.exe` under a `ProgramData` path, while the final live process on `DBTEST01` was observed under `Program Files`.

# Server Findings

## RDPDISC01

### Pre-Install Baseline

The baseline probe on `RDPDISC01` showed:

- operating system: `Windows Server 2022 Datacenter Azure Edition`
- host state: `WORKGROUP`
- no `RDPWin` tree present under the probed `ProgramData` location
- successful DNS resolution for `DBTEST01`
- successful connectivity to `DBTEST01` on:
  - `135`
  - `139`
  - `445`
- no open connectivity to `DBTEST01` on:
  - `1583`
  - `3351`
- established SMB traffic from `RDPDISC01` to `DBTEST01`

Interpretation:

`RDPDISC01` had basic backend reachability before install and could already resolve and reach the DB server over SMB, but it did not yet show the Actian/Pervasive client footprint or the probed `RDPWin` application tree.

### Post-Install State

The reviewed post-install `AdHoc` runs on `RDPDISC01` showed:

- `Actian Zen Client Cache Engine` running
- `Pervasive ODBC Interface` present
- `Pervasive ODBC Unicode Interface` present
- `Pervasive ODBC Client Interface` present
- `RDPWinPath.txt` present under the `RDPWin` `ProgramData` tree

Interpretation:

The discovery host clearly transitioned to a client-installed state. The combination of the Actian client cache engine, Pervasive ODBC components, and `RDPWinPath.txt` indicates the host received meaningful client-side RDPWin and database-access configuration.

### Confidence Level

Confidence is moderate, not high, because the later discovery-host network tests were aimed at `DB01` and `DB02` rather than `DBTEST01`. That makes the post-install discovery-to-DB connectivity output unreliable as a direct migration signal.

## DBTEST01

### Install Progression Reconstructed from Probe Timing

The DB server probes provide a clear sequence:

#### Early State

At the earliest reviewed DB probe, the expected `RDPWin` path under `ProgramData` was not yet visible and no `RDPWin` services had been captured.

#### Actian/Zen Layer Present

The next reviewed DB probe showed:

- `Actian Zen Cloud Server` running
- Pervasive ODBC drivers present in both 64-bit and 32-bit registry views
- `demodata` ODBC data sources present

Interpretation:

This is strong evidence that the backend database engine layer was installed and registered successfully enough to expose the expected ODBC footprint.

#### RDPWin Service Layer Present

A later DB probe showed:

- `RDPWin Monitor` installed
- `RDPWin Monitor GDS` installed
- `RDPWin Monitor GDS Reservations` running

Interpretation:

This is the first clear sign that the RDPWin server-side service stack had been installed.

#### Final Reviewed DB State

The final DB probe reviewed showed:

- `RDPWin Monitor GDS Reservations` still running
- `RDPWin.exe` actively running from:
  - `C:\Program Files\ResortDataProcessing\RDPWinMSI\RDPWin.exe`
- listeners active on:
  - `1583`
  - `3351`
- an established `RDPWin.exe` connection to port `1583`

Interpretation:

This is the strongest runtime evidence in the capture set. It shows the DB host in an active post-install state with the database engine listening and the application process running against it.

### Confidence Level

Confidence is high that `DBTEST01` reached a live and functional server-side state during the capture window. This is the cleanest evidence available in the full probe set.

# Migration-Relevant Conclusions

For migration planning, the probe output supports these practical conclusions:

1. `DBTEST01` is the stronger reference point for backend migration behavior because it shows the best runtime evidence of the live application and database stack.
2. `RDPDISC01` appears to have the client-side dependencies and path artifacts needed to act as the session host/front-end system.
3. The observed `RDPWin.exe` runtime path on `DBTEST01` should be treated as important when validating future installs, because it differs from the probe’s assumed executable path.
4. The probe data supports the architecture assumption that:
   - `DBTEST01` is the backend data and service host
   - `RDPDISC01` is the session-host or application-access host

# What Can Be Relied On

The following statements are supported by the reviewed probe data:

- The DB server reached a live state with Actian Zen running and listening.
- The DB server had the `RDPWin` monitor service layer installed.
- The DB server had an active `RDPWin.exe` process captured in the final reviewed probe.
- The discovery host showed the expected client-side Actian/Pervasive footprint after install.
- The discovery host had evidence of `RDPWin` path/config material being written.

# What Still Needs Separate Validation

These items should be treated as separate validation tasks rather than conclusions from this probe package:

- exact contents of `RDPWin` configuration files
- final discovery-to-DB connectivity using corrected probe targets
- end-user launch validation from the AVD or session-host access path
- any production cutover readiness decision

# Recommended Follow-Up

If a cleaner migration evidence package is needed later, the next probe run should:

1. target `DBTEST01` explicitly on both servers
2. include the explicit backend share paths
3. enable config-text capture
4. inventory both the `ProgramData` and `Program Files` `RDPWin.exe` paths
5. fix the installed-software collector so that the software inventory completes successfully

# Bottom Line

The probe data supports a credible handoff statement:

`RDPDISC01` shows the expected client-side install footprint, while `DBTEST01` shows the strongest server-side proof of life: Actian Zen active, RDPWin services installed, backend listeners present, and a live `RDPWin.exe` process captured.

That is useful migration context. It is not, by itself, a complete validation package.
