<#
.SYNOPSIS
  Scaffolds a stable RDPWin desktop session on Windows Server 2022.

.DESCRIPTION
  Non-admin shaping uses HKCU Explorer policies and optional AppLocker on a
  dedicated local group. Explorer.exe is never stopped or replaced; that keeps
  RDPWin stable. AppLocker defaults to AuditOnly + BroadExeAllowlist so it
  never blocks logon; Enforced+tight lists are opt-in after audit. For lockout
  recovery run scripts/Recover-RDPWinLabAccess.ps1 or Azure Run Command.
#>
param(
    [string]$PolicyConfigPath
)

$ErrorActionPreference = 'Stop'

$policyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
$runKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
$serverManagerKey = 'HKLM:\SOFTWARE\Microsoft\ServerManager'
$workingRoot = 'C:\ProgramData\RDPWinLab'
$launcherPath = Join-Path $workingRoot 'Start-RDPWinDesktop.ps1'
$sessionPolicyPath = Join-Path $workingRoot 'SessionPolicy.json'
$appLockerRoot = Join-Path $workingRoot 'AppLocker'
$appLockerPolicyPath = Join-Path $appLockerRoot 'RDPWinLab-AppLocker.xml'
$taskName = 'RDPWin Desktop Launcher'
$taskPath = '\RDPWinLab\'
$taskCommand = 'PowerShell.exe'
$taskArguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$launcherPath`""

function Get-DefaultPolicyJson {
    @'
{
  "Version": 1,
  "ApplyToUnmatchedUsers": false,
  "RestrictedUserAccounts": [
    "FSHOSTEDTEST\\CSS0",
    "FSHOSTEDTEST\\HSC1",
    "FSHOSTEDTEST\\TCS2"
  ],
  "AppLocker": {
    "Enabled": false,
    "Mode": "AuditOnly",
    "AllowEnforcedMode": false,
    "BroadExeAllowlist": true,
    "RestrictedLocalGroup": "RDPWinLabRestrictedUsers",
    "AllowedPaths": [
      "%WINDIR%\\*",
      "%PROGRAMFILES%\\*",
      "%PROGRAMFILES(X86)%\\*",
      "C:\\ProgramData\\RDPWinLab\\*",
      "C:\\ProgramData\\ResortDataProcessing\\RDPWin\\*",
      "C:\\Program Files\\ResortDataProcessing\\RDPWinMSI\\*"
    ],
    "Notes": "Safe default: AuditOnly + BroadExeAllowlist true — AppLocker does not block executables; it only logs. Use Event Viewer AppLocker Operational to build a tight list, then test Enforced in a maintenance window. If locked out with Enforced, use Azure VM Run Command: Stop-Service AppIDSvc -Force; Set-Service AppIDSvc -StartupType Disabled."
  },
  "Profiles": [
    {
      "Name": "CSS",
      "MatchPatterns": [
        "^CSS\\d*$",
        "^[^\\\\]+\\\\CSS\\d*$",
        "^CSS\\d+@"
      ],
      "AutoLaunchRDPWin": true,
      "LogoffOnExit": true,
      "Policy": {
        "DisableTaskbarSettings": true,
        "DisableTrayContextMenu": true,
        "LockTaskbar": true,
        "DisableStartMenuChanges": true,
        "HideStartMenuMorePrograms": true,
        "HideStartMenuMostUsed": true,
        "DisableSearchUI": true,
        "DisableWindowsHotkeys": true,
        "HideNotificationArea": false,
        "RemoveRunMenu": true,
        "HideCommonProgramGroups": true,
        "HideRecentDocumentsMenu": true,
        "DisableTaskbarToolbars": true,
        "RemoveHelpFromStartMenu": true,
        "DisableNotificationCenter": true,
        "DisableStartMenuProgramTracking": true,
        "RemoveShutdownFromStartMenu": false,
        "BlockControlPanel": false,
        "DisableRegistryEditor": true
      }
    },
    {
      "Name": "HSC",
      "MatchPatterns": [
        "^HSC\\d*$",
        "^[^\\\\]+\\\\HSC\\d*$",
        "^HSC\\d+@"
      ],
      "AutoLaunchRDPWin": true,
      "LogoffOnExit": true,
      "Policy": {
        "DisableTaskbarSettings": true,
        "DisableTrayContextMenu": true,
        "LockTaskbar": true,
        "DisableStartMenuChanges": true,
        "HideStartMenuMorePrograms": true,
        "HideStartMenuMostUsed": true,
        "DisableSearchUI": true,
        "DisableWindowsHotkeys": true,
        "HideNotificationArea": false,
        "RemoveRunMenu": true,
        "HideCommonProgramGroups": true,
        "HideRecentDocumentsMenu": true,
        "DisableTaskbarToolbars": true,
        "RemoveHelpFromStartMenu": true,
        "DisableNotificationCenter": true,
        "DisableStartMenuProgramTracking": true,
        "RemoveShutdownFromStartMenu": false,
        "BlockControlPanel": false,
        "DisableRegistryEditor": true
      }
    },
    {
      "Name": "TCS",
      "MatchPatterns": [
        "^TCS\\d*$",
        "^[^\\\\]+\\\\TCS\\d*$",
        "^TCS\\d+@"
      ],
      "AutoLaunchRDPWin": true,
      "LogoffOnExit": true,
      "Policy": {
        "DisableTaskbarSettings": true,
        "DisableTrayContextMenu": true,
        "LockTaskbar": true,
        "DisableStartMenuChanges": true,
        "HideStartMenuMorePrograms": true,
        "HideStartMenuMostUsed": true,
        "DisableSearchUI": true,
        "DisableWindowsHotkeys": true,
        "HideNotificationArea": false,
        "RemoveRunMenu": true,
        "HideCommonProgramGroups": true,
        "HideRecentDocumentsMenu": true,
        "DisableTaskbarToolbars": true,
        "RemoveHelpFromStartMenu": true,
        "DisableNotificationCenter": true,
        "DisableStartMenuProgramTracking": true,
        "RemoveShutdownFromStartMenu": false,
        "BlockControlPanel": false,
        "DisableRegistryEditor": true
      }
    }
  ]
}
'@
}

function ConvertTo-AppLockerEnforcementMode {
    param([string]$Mode)

    $normalizedMode = ''
    if ($null -ne $Mode) {
        $normalizedMode = $Mode.Trim().ToLowerInvariant()
    }

    switch ($normalizedMode) {
        'enforced' { return 'Enabled' }
        'enabled' { return 'Enabled' }
        'audit' { return 'AuditOnly' }
        'auditonly' { return 'AuditOnly' }
        default { return 'AuditOnly' }
    }
}

function New-AppLockerFilePathRuleXml {
    param(
        [string]$Name,
        [string]$Description,
        [string]$UserOrGroupSid,
        [string]$Path,
        [string]$Action = 'Allow'
    )

    $safeName = [System.Security.SecurityElement]::Escape($Name)
    $safeDescription = [System.Security.SecurityElement]::Escape($Description)
    $safeSid = [System.Security.SecurityElement]::Escape($UserOrGroupSid)
    $safePath = [System.Security.SecurityElement]::Escape($Path)
    $ruleId = [guid]::NewGuid().Guid

    return @"
    <FilePathRule Id="$ruleId" Name="$safeName" Description="$safeDescription" UserOrGroupSid="$safeSid" Action="$Action">
      <Conditions>
        <FilePathCondition Path="$safePath" />
      </Conditions>
    </FilePathRule>
"@
}

function Ensure-RestrictedLocalGroup {
    param(
        [string]$GroupName,
        [string[]]$Members
    )

    $group = Get-LocalGroup -Name $GroupName -ErrorAction SilentlyContinue
    if (-not $group) {
        New-LocalGroup -Name $GroupName -Description 'RDPWin lab restricted users' | Out-Null
    }

    $existingMembers = @()
    try {
        $existingMembers = @(Get-LocalGroupMember -Group $GroupName -ErrorAction Stop | ForEach-Object { $_.Name })
    }
    catch {
        $existingMembers = @()
    }

    foreach ($member in @($Members | Where-Object { $_ })) {
        if ($existingMembers -contains $member) {
            continue
        }

        try {
            Add-LocalGroupMember -Group $GroupName -Member $member -ErrorAction Stop
        }
        catch {
            Write-Warning "Could not add $member to local group $GroupName. $($_.Exception.Message)"
        }
    }

    return (Get-LocalGroup -Name $GroupName -ErrorAction Stop)
}

function Build-AppLockerPolicyXml {
    param(
        [string]$RestrictedGroupSid,
        [string]$EnforcementMode,
        [string[]]$AllowedPaths,
        [bool]$BroadExeAllowlist
    )

    $allowRules = New-Object System.Collections.Generic.List[string]

    if ($BroadExeAllowlist) {
        $allowRules.Add((New-AppLockerFilePathRuleXml `
            -Name 'Allow Windows' `
            -Description 'Broad allow for Windows directory (legacy / lab permissive mode).' `
            -UserOrGroupSid $RestrictedGroupSid `
            -Path '%WINDIR%\*'))
        $allowRules.Add((New-AppLockerFilePathRuleXml `
            -Name 'Allow Program Files' `
            -Description 'Broad allow for 64-bit Program Files.' `
            -UserOrGroupSid $RestrictedGroupSid `
            -Path '%PROGRAMFILES%\*'))
        $allowRules.Add((New-AppLockerFilePathRuleXml `
            -Name 'Allow Program Files x86' `
            -Description 'Broad allow for 32-bit Program Files.' `
            -UserOrGroupSid $RestrictedGroupSid `
            -Path '%PROGRAMFILES(X86)%\*'))
    }

    foreach ($path in @($AllowedPaths | Where-Object { $_ })) {
        if ($BroadExeAllowlist -and ($path -in @('%WINDIR%\*', '%PROGRAMFILES%\*', '%PROGRAMFILES(X86)%\*'))) {
            continue
        }

        $allowRules.Add((New-AppLockerFilePathRuleXml `
            -Name "Allow $path" `
            -Description 'Lab allow path for RDPWin desktop flow.' `
            -UserOrGroupSid $RestrictedGroupSid `
            -Path $path))
    }

    if ($allowRules.Count -eq 0) {
        throw 'AppLocker has no Exe allow rules. Set AllowedPaths or enable BroadExeAllowlist.'
    }

    $allowRulesText = $allowRules -join [Environment]::NewLine

    return @"
<?xml version="1.0" encoding="utf-8"?>
<AppLockerPolicy Version="1">
  <RuleCollection Type="Exe" EnforcementMode="$EnforcementMode">
$allowRulesText
  </RuleCollection>
  <RuleCollection Type="Msi" EnforcementMode="NotConfigured" />
  <RuleCollection Type="Script" EnforcementMode="NotConfigured" />
  <RuleCollection Type="Dll" EnforcementMode="NotConfigured" />
  <RuleCollection Type="Appx" EnforcementMode="NotConfigured" />
</AppLockerPolicy>
"@
}

function Initialize-AppLockerScaffold {
    param($Config)

    $appLocker = $Config.AppLocker
    if ($null -eq $appLocker -or -not [bool]$appLocker.Enabled) {
        return @{
            Enabled = $false
            Mode = 'Disabled'
            GroupName = $null
            GroupSid = $null
            RestrictedAccounts = @()
            Error = $null
        }
    }

    $groupName = $appLocker.RestrictedLocalGroup
    if (-not $groupName) {
        $groupName = 'RDPWinLabRestrictedUsers'
    }

    try {
        $restrictedAccounts = @($Config.RestrictedUserAccounts | Where-Object { $_ })
        $group = Ensure-RestrictedLocalGroup -GroupName $groupName -Members $restrictedAccounts
        $groupSid = $group.SID.Value
        $requestedMode = ConvertTo-AppLockerEnforcementMode -Mode $appLocker.Mode
        $allowEnforcedMode = $false
        if ($null -ne $appLocker.AllowEnforcedMode) {
            $allowEnforcedMode = [bool]$appLocker.AllowEnforcedMode
        }

        $enforcementMode = $requestedMode
        $modeDowngraded = $false
        if ($requestedMode -eq 'Enabled' -and -not $allowEnforcedMode) {
            $enforcementMode = 'AuditOnly'
            $modeDowngraded = $true
            Write-Warning 'AppLocker requested Enforced mode, but AllowEnforcedMode is not true. Falling back to AuditOnly to avoid lockout.'
        }

        $allowedPaths = @($appLocker.AllowedPaths | Where-Object { $_ })
        $broadExeAllowlist = $false
        if ($null -ne $appLocker.BroadExeAllowlist) {
            $broadExeAllowlist = [bool]$appLocker.BroadExeAllowlist
        }

        New-Item -Path $appLockerRoot -ItemType Directory -Force | Out-Null
        $policyXml = Build-AppLockerPolicyXml `
            -RestrictedGroupSid $groupSid `
            -EnforcementMode $enforcementMode `
            -AllowedPaths $allowedPaths `
            -BroadExeAllowlist $broadExeAllowlist
        Set-Content -Path $appLockerPolicyPath -Value $policyXml -Encoding UTF8

        $appIdService = Get-Service -Name 'AppIDSvc' -ErrorAction Stop
        if ($appIdService.StartType -ne 'Automatic') {
            try {
                Set-Service -Name 'AppIDSvc' -StartupType Automatic -ErrorAction Stop
            }
            catch {
                Write-Warning "Could not set AppIDSvc startup type to Automatic. $($_.Exception.Message)"
            }
        }

        if ($appIdService.Status -ne 'Running') {
            Start-Service -Name 'AppIDSvc' -ErrorAction Stop
        }

        Set-AppLockerPolicy -XmlPolicy $appLockerPolicyPath -Merge -ErrorAction Stop

        return @{
            Enabled = $true
            RequestedMode = $requestedMode
            Mode = $enforcementMode
            ModeDowngraded = $modeDowngraded
            AllowEnforcedMode = $allowEnforcedMode
            BroadExeAllowlist = $broadExeAllowlist
            GroupName = $groupName
            GroupSid = $groupSid
            RestrictedAccounts = $restrictedAccounts
            Error = $null
        }
    }
    catch {
        Write-Warning "AppLocker scaffold could not be fully applied. $($_.Exception.Message)"

        return @{
            Enabled = $false
            Mode = 'Failed'
            RequestedMode = $null
            ModeDowngraded = $false
            AllowEnforcedMode = $false
            GroupName = $groupName
            GroupSid = $null
            RestrictedAccounts = @($Config.RestrictedUserAccounts | Where-Object { $_ })
            Error = $_.Exception.Message
        }
    }
}

function Resolve-PolicyConfigJson {
    if ($PolicyConfigPath -and (Test-Path -Path $PolicyConfigPath)) {
        return (Get-Content -Path $PolicyConfigPath -Raw)
    }

    $repoCandidate = Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'config\rdpwin-session-policy.json'
    if (Test-Path -Path $repoCandidate) {
        return (Get-Content -Path $repoCandidate -Raw)
    }

    return (Get-DefaultPolicyJson)
}

New-Item -Path $workingRoot -ItemType Directory -Force | Out-Null
New-Item -Path $appLockerRoot -ItemType Directory -Force | Out-Null
New-Item -Path $policyKey -ItemType Directory -Force | Out-Null
New-Item -Path $runKey -ItemType Directory -Force | Out-Null
if (-not (Test-Path -Path $serverManagerKey)) {
    New-Item -Path $serverManagerKey -ItemType Directory -Force | Out-Null
}

$policyJson = Resolve-PolicyConfigJson
$config = $policyJson | ConvertFrom-Json
Set-Content -Path $sessionPolicyPath -Value $policyJson -Encoding ASCII
$appLockerState = Initialize-AppLockerScaffold -Config $config

$launcherScript = @'
$ErrorActionPreference = 'Stop'

$workingRoot = 'C:\ProgramData\RDPWinLab'
$logPath = Join-Path $workingRoot 'DesktopLaunch.log'
$sessionPolicyPath = Join-Path $workingRoot 'SessionPolicy.json'
$appCandidates = @(
    'C:\Program Files\ResortDataProcessing\RDPWinMSI\RDPWin.exe',
    'C:\ProgramData\ResortDataProcessing\RDPWin\RDPWin5Client\RDPWin.exe'
)

function Write-DesktopLog {
    param([string]$Message)

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $logPath -Value "$timestamp $Message"
}

function Get-ArrayValues {
    param($Value)

    if ($null -eq $Value) {
        return @()
    }

    return @($Value)
}

function Get-CurrentSessionId {
    try {
        return [System.Diagnostics.Process]::GetCurrentProcess().SessionId
    }
    catch {
        return $null
    }
}

function Get-SessionProcesses {
    param([string]$ProcessName)

    $sessionId = Get-CurrentSessionId
    if ($null -eq $sessionId) {
        return @()
    }

    return @(Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq $sessionId })
}

function Get-NormalizedUserNames {
    $names = New-Object System.Collections.Generic.List[string]
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()

    if ($identity.Name) {
        $names.Add($identity.Name)
    }

    if ($env:USERNAME) {
        $names.Add($env:USERNAME)
    }

    if ($env:USERDOMAIN -and $env:USERNAME) {
        $names.Add("$($env:USERDOMAIN)\$($env:USERNAME)")
    }

    if ($env:USERDNSDOMAIN -and $env:USERNAME) {
        $names.Add("$($env:USERNAME)@$($env:USERDNSDOMAIN)")
    }

    return $names | Select-Object -Unique
}

function Test-PolicyMatch {
    param(
        $Profile,
        [string[]]$CandidateNames
    )

    foreach ($pattern in (Get-ArrayValues -Value $Profile.MatchPatterns)) {
        foreach ($candidate in $CandidateNames) {
            if ($candidate -match $pattern) {
                return $true
            }
        }
    }

    return $false
}

function Resolve-SessionProfile {
    param($Config)

    $candidateNames = Get-NormalizedUserNames
    foreach ($profile in (Get-ArrayValues -Value $Config.Profiles)) {
        if (Test-PolicyMatch -Profile $profile -CandidateNames $candidateNames) {
            return $profile
        }
    }

    return $null
}

function Set-DwordValue {
    param(
        [string]$Path,
        [string]$Name,
        [bool]$Enabled
    )

    try {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
        if ($Enabled) {
            New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value 1 -Force | Out-Null
        } else {
            Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        }

        return $true
    }
    catch {
        Write-DesktopLog "Could not update $Path\\$Name. $($_.Exception.Message)"
        return $false
    }
}

function Apply-ProfilePolicy {
    param($Profile)

    # Explorer.exe stays running. Restriction is policy + AppLocker, not shell replacement.
    $advancedKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $userPolicyKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'
    $systemPolicyKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System'
    $winExplorerPolicyKey = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'

    $policy = $Profile.Policy
    if ($null -eq $policy) {
        return
    }

    function Get-PolicyBool {
        param(
            $Policy,
            [string]$PropertyName,
            [bool]$DefaultIfMissing
        )

        if ($null -eq $Policy.$PropertyName) {
            return $DefaultIfMissing
        }

        return [bool]$Policy.$PropertyName
    }

    # Give the user shell time to finish initializing HKCU-backed policy paths.
    Start-Sleep -Seconds 10

    $trackOff = Get-PolicyBool -Policy $policy -PropertyName 'DisableStartMenuProgramTracking' -DefaultIfMissing $true

    try {
        New-Item -Path $advancedKey -ItemType Directory -Force | Out-Null
        if ($trackOff) {
            New-ItemProperty -Path $advancedKey -Name 'Start_TrackProgs' -PropertyType DWord -Value 0 -Force | Out-Null
        } else {
            Remove-ItemProperty -Path $advancedKey -Name 'Start_TrackProgs' -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-DesktopLog "Could not update $advancedKey\\Start_TrackProgs. $($_.Exception.Message)"
    }

    $results = @(
        @{ Name = 'LockTaskbar'; Applied = Set-DwordValue -Path $advancedKey -Name 'LockTaskbar' -Enabled ([bool]$policy.LockTaskbar) }
        @{ Name = 'NoSetTaskbar'; Applied = Set-DwordValue -Path $userPolicyKey -Name 'NoSetTaskbar' -Enabled ([bool]$policy.DisableTaskbarSettings) }
        @{ Name = 'NoTrayContextMenu'; Applied = Set-DwordValue -Path $userPolicyKey -Name 'NoTrayContextMenu' -Enabled ([bool]$policy.DisableTrayContextMenu) }
        @{ Name = 'NoTrayItemsDisplay'; Applied = Set-DwordValue -Path $userPolicyKey -Name 'NoTrayItemsDisplay' -Enabled ([bool]$policy.HideNotificationArea) }
        @{ Name = 'NoChangeStartMenu'; Applied = Set-DwordValue -Path $userPolicyKey -Name 'NoChangeStartMenu' -Enabled ([bool]$policy.DisableStartMenuChanges) }
        @{ Name = 'NoStartMenuMorePrograms'; Applied = Set-DwordValue -Path $userPolicyKey -Name 'NoStartMenuMorePrograms' -Enabled ([bool]$policy.HideStartMenuMorePrograms) }
        @{ Name = 'NoStartMenuMFUprogramsList'; Applied = Set-DwordValue -Path $userPolicyKey -Name 'NoStartMenuMFUprogramsList' -Enabled ([bool]$policy.HideStartMenuMostUsed) }
        @{ Name = 'NoFind'; Applied = Set-DwordValue -Path $userPolicyKey -Name 'NoFind' -Enabled ([bool]$policy.DisableSearchUI) }
        @{ Name = 'NoWinKeys'; Applied = Set-DwordValue -Path $userPolicyKey -Name 'NoWinKeys' -Enabled ([bool]$policy.DisableWindowsHotkeys) }
        @{ Name = 'NoRun'; Applied = Set-DwordValue -Path $userPolicyKey -Name 'NoRun' -Enabled (Get-PolicyBool -Policy $policy -PropertyName 'RemoveRunMenu' -DefaultIfMissing $true) }
        @{ Name = 'NoCommonGroups'; Applied = Set-DwordValue -Path $userPolicyKey -Name 'NoCommonGroups' -Enabled (Get-PolicyBool -Policy $policy -PropertyName 'HideCommonProgramGroups' -DefaultIfMissing $true) }
        @{ Name = 'NoRecentDocsMenu'; Applied = Set-DwordValue -Path $userPolicyKey -Name 'NoRecentDocsMenu' -Enabled (Get-PolicyBool -Policy $policy -PropertyName 'HideRecentDocumentsMenu' -DefaultIfMissing $true) }
        @{ Name = 'NoToolbarsOnTaskbar'; Applied = Set-DwordValue -Path $userPolicyKey -Name 'NoToolbarsOnTaskbar' -Enabled (Get-PolicyBool -Policy $policy -PropertyName 'DisableTaskbarToolbars' -DefaultIfMissing $true) }
        @{ Name = 'NoSMHelp'; Applied = Set-DwordValue -Path $userPolicyKey -Name 'NoSMHelp' -Enabled (Get-PolicyBool -Policy $policy -PropertyName 'RemoveHelpFromStartMenu' -DefaultIfMissing $true) }
        @{ Name = 'NoClose'; Applied = Set-DwordValue -Path $userPolicyKey -Name 'NoClose' -Enabled (Get-PolicyBool -Policy $policy -PropertyName 'RemoveShutdownFromStartMenu' -DefaultIfMissing $false) }
        @{ Name = 'NoControlPanel'; Applied = Set-DwordValue -Path $userPolicyKey -Name 'NoControlPanel' -Enabled (Get-PolicyBool -Policy $policy -PropertyName 'BlockControlPanel' -DefaultIfMissing $false) }
        @{ Name = 'DisableNotificationCenter'; Applied = Set-DwordValue -Path $winExplorerPolicyKey -Name 'DisableNotificationCenter' -Enabled (Get-PolicyBool -Policy $policy -PropertyName 'DisableNotificationCenter' -DefaultIfMissing $true) }
        @{ Name = 'DisableRegistryTools'; Applied = Set-DwordValue -Path $systemPolicyKey -Name 'DisableRegistryTools' -Enabled (Get-PolicyBool -Policy $policy -PropertyName 'DisableRegistryEditor' -DefaultIfMissing $true) }
    )

    $applied = @($results | Where-Object { $_.Applied } | ForEach-Object { $_.Name })
    $skipped = @($results | Where-Object { -not $_.Applied } | ForEach-Object { $_.Name })

    if ($applied.Count -gt 0) {
        Write-DesktopLog "Applied shell policy values: $($applied -join ', ')."
    }

    if ($skipped.Count -gt 0) {
        Write-DesktopLog "Skipped shell policy values after registry denial or write failure: $($skipped -join ', ')."
    }
}

try {
    if (-not (Test-Path -Path $sessionPolicyPath)) {
        Write-DesktopLog 'SessionPolicy.json was not found. Leaving desktop intact.'
        exit 0
    }

    $config = Get-Content -Path $sessionPolicyPath -Raw | ConvertFrom-Json
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $userName = $identity.Name

    Write-DesktopLog "Launcher start for $userName in session $env:SESSIONNAME."

    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-DesktopLog 'Administrative user detected; leaving normal desktop session intact.'
        exit 0
    }

    $profile = Resolve-SessionProfile -Config $config
    if ($null -eq $profile -and -not [bool]$config.ApplyToUnmatchedUsers) {
        Write-DesktopLog "No CSS/HSC/TCS policy profile matched $userName; leaving desktop intact."
        exit 0
    }

    if ($profile) {
        Write-DesktopLog "Matched policy profile $($profile.Name) for $userName."
        Apply-ProfilePolicy -Profile $profile
    } else {
        Write-DesktopLog "No explicit policy profile matched $userName, but ApplyToUnmatchedUsers is enabled."
    }

    $currentSessionId = Get-CurrentSessionId
    Get-Process -Name 'ServerManager' -ErrorAction SilentlyContinue |
        Where-Object { $_.SessionId -eq $currentSessionId } |
        Stop-Process -Force

    $appPath = $appCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $appPath) {
        Write-DesktopLog 'RDPWin executable was not found. Leaving session intact.'
        exit 0
    }

    $autoLaunch = $true
    if ($profile -and $null -ne $profile.AutoLaunchRDPWin) {
        $autoLaunch = [bool]$profile.AutoLaunchRDPWin
    }

    if ($autoLaunch) {
        $existing = Get-SessionProcesses -ProcessName 'RDPWin'
        if (-not $existing) {
            Start-Process -FilePath $appPath -WorkingDirectory (Split-Path -Path $appPath -Parent) | Out-Null
            Write-DesktopLog "Started RDPWin from $appPath."
        } else {
            Write-DesktopLog 'RDPWin process already present at logon; monitoring existing process set.'
        }
    } else {
        Write-DesktopLog 'Auto-launch is disabled for the matched profile.'
        exit 0
    }

    $appeared = $false
    foreach ($attempt in 1..30) {
        if (Get-SessionProcesses -ProcessName 'RDPWin') {
            $appeared = $true
            break
        }

        Start-Sleep -Seconds 1
    }

    if (-not $appeared) {
        Write-DesktopLog 'RDPWin never appeared after launch attempt. Leaving session intact.'
        exit 0
    }

    while (Get-SessionProcesses -ProcessName 'RDPWin') {
        Start-Sleep -Seconds 2
    }

    $logoffOnExit = $true
    if ($profile -and $null -ne $profile.LogoffOnExit) {
        $logoffOnExit = [bool]$profile.LogoffOnExit
    }

    if ($logoffOnExit) {
        Write-DesktopLog 'RDPWin exited; logging off session.'
        shutdown.exe /l /f
    } else {
        Write-DesktopLog 'RDPWin exited; profile leaves the desktop session intact.'
    }
}
catch {
    Write-DesktopLog "Unhandled error: $($_.Exception.Message)"
    exit 0
}
'@

Set-Content -Path $launcherPath -Value $launcherScript -Encoding ASCII

Remove-ItemProperty -Path $runKey -Name 'RDPWinDesktopLauncher' -ErrorAction SilentlyContinue

$restrictedAccounts = @($config.RestrictedUserAccounts | Where-Object { $_ })
$taskRegistrationMode = 'ScheduledTaskPerUser'
$registeredTaskNames = New-Object System.Collections.Generic.List[string]
$taskRegistrationErrors = New-Object System.Collections.Generic.List[string]

foreach ($account in $restrictedAccounts) {
    $safeTaskSuffix = ($account -replace '[\\/:*?"<>|]', '_')
    $perUserTaskName = "$taskName - $safeTaskSuffix"
    $taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Launch RDPWin for $account at logon and optionally log off when it exits.</Description>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
      <UserId>$account</UserId>
    </LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$account</UserId>
      <RunLevel>LeastPrivilege</RunLevel>
      <LogonType>InteractiveToken</LogonType>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>$taskCommand</Command>
      <Arguments>$taskArguments</Arguments>
    </Exec>
  </Actions>
</Task>
"@

    try {
        Register-ScheduledTask `
            -TaskName $perUserTaskName `
            -TaskPath $taskPath `
            -Xml $taskXml `
            -Force | Out-Null
        $registeredTaskNames.Add($perUserTaskName)
    }
    catch {
        $taskRegistrationErrors.Add("$account: $($_.Exception.Message)")
    }
}

if ($registeredTaskNames.Count -eq 0) {
    $taskRegistrationMode = 'NoTasksRegistered'
}

New-ItemProperty -Path $serverManagerKey `
    -Name 'DoNotOpenServerManagerAtLogon' `
    -PropertyType DWord `
    -Value 1 `
    -Force | Out-Null
Remove-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Recurse -Force -ErrorAction SilentlyContinue

# End sessions that hit a timeout instead of leaving them disconnected.
New-ItemProperty -Path $policyKey -Name 'fResetBroken' -PropertyType DWord -Value 1 -Force | Out-Null

# Clean up disconnected sessions after one minute so reconnects do not leave
# abandoned desktops behind.
New-ItemProperty -Path $policyKey -Name 'MaxDisconnectionTime' -PropertyType DWord -Value 60000 -Force | Out-Null

gpupdate /target:computer /force | Out-Null

Write-Output "LauncherPath=$launcherPath"
Write-Output "SessionPolicyPath=$sessionPolicyPath"
Write-Output "AppLockerPolicyPath=$appLockerPolicyPath"
Write-Output "AppLockerEnabled=$($appLockerState.Enabled)"
if ($appLockerState.Enabled) {
    if ($null -ne $appLockerState.RequestedMode) {
        Write-Output "AppLockerRequestedMode=$($appLockerState.RequestedMode)"
    }
    Write-Output "AppLockerMode=$($appLockerState.Mode)"
    Write-Output "AppLockerAllowEnforcedMode=$($appLockerState.AllowEnforcedMode)"
    Write-Output "AppLockerModeDowngraded=$($appLockerState.ModeDowngraded)"
    Write-Output "AppLockerBroadExeAllowlist=$($appLockerState.BroadExeAllowlist)"
    Write-Output "AppLockerRestrictedLocalGroup=$($appLockerState.GroupName)"
    Write-Output "AppLockerRestrictedLocalGroupSid=$($appLockerState.GroupSid)"
    if ($appLockerState.RestrictedAccounts.Count -gt 0) {
        Write-Output "AppLockerRestrictedAccounts=$($appLockerState.RestrictedAccounts -join ',')"
    }
} elseif ($appLockerState.Error) {
    Write-Output "AppLockerError=$($appLockerState.Error)"
}
Write-Output "TaskRegistrationMode=$taskRegistrationMode"
if ($registeredTaskNames.Count -gt 0) {
    foreach ($registeredTaskName in $registeredTaskNames) {
        Get-ScheduledTask -TaskPath $taskPath -TaskName $registeredTaskName | Select-Object TaskPath, TaskName, State
    }
}
if ($taskRegistrationErrors.Count -gt 0) {
    Write-Output "TaskRegistrationErrors=$($taskRegistrationErrors -join ' | ')"
}
if ($appLockerState.Enabled) {
    cmd /c sc qc AppIDSvc
}
cmd /c reg query "HKLM\SOFTWARE\Microsoft\ServerManager" /v DoNotOpenServerManagerAtLogon
cmd /c reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fResetBroken
cmd /c reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v MaxDisconnectionTime
