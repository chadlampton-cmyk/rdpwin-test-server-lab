$ErrorActionPreference = 'Stop'

$policyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
$runKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
$serverManagerKey = 'HKLM:\SOFTWARE\Microsoft\ServerManager'
$workingRoot = 'C:\ProgramData\RDPWinLab'
$launcherPath = Join-Path $workingRoot 'Start-RDPWinDesktop.ps1'

New-Item -Path $workingRoot -ItemType Directory -Force | Out-Null
New-Item -Path $policyKey -ItemType Directory -Force | Out-Null
New-Item -Path $runKey -ItemType Directory -Force | Out-Null
if (-not (Test-Path $serverManagerKey)) {
    New-Item -Path $serverManagerKey -ItemType Directory -Force | Out-Null
}

$launcherScript = @'
$ErrorActionPreference = 'Stop'

$logPath = 'C:\ProgramData\RDPWinLab\DesktopLaunch.log'
$appCandidates = @(
    'C:\Program Files\ResortDataProcessing\RDPWinMSI\RDPWin.exe',
    'C:\ProgramData\ResortDataProcessing\RDPWin\RDPWin5Client\RDPWin.exe'
)

function Write-DesktopLog {
    param([string]$Message)

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $logPath -Value "$timestamp $Message"
}

try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $userName = $identity.Name

    Write-DesktopLog "Launcher start for $userName in session $env:SESSIONNAME."

    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-DesktopLog 'Administrative user detected; leaving normal desktop session intact.'
        exit 0
    }

    $appPath = $appCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $appPath) {
        Write-DesktopLog 'RDPWin executable was not found. Logging off session.'
        shutdown.exe /l /f
        exit 1
    }

    $existing = Get-Process -Name 'RDPWin' -ErrorAction SilentlyContinue
    if (-not $existing) {
        Start-Process -FilePath $appPath -WorkingDirectory (Split-Path -Path $appPath -Parent) | Out-Null
        Write-DesktopLog "Started RDPWin from $appPath."
    } else {
        Write-DesktopLog 'RDPWin process already present at logon; monitoring existing process set.'
    }

    $appeared = $false
    foreach ($attempt in 1..30) {
        if (Get-Process -Name 'RDPWin' -ErrorAction SilentlyContinue) {
            $appeared = $true
            break
        }

        Start-Sleep -Seconds 1
    }

    if (-not $appeared) {
        Write-DesktopLog 'RDPWin never appeared after launch attempt. Logging off session.'
        shutdown.exe /l /f
        exit 1
    }

    $advancedKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $userPolicyKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'

    foreach ($valueName in 'TaskbarAutoHideInTabletMode', 'TaskbarAutoHide') {
        Remove-ItemProperty -Path $advancedKey -Name $valueName -ErrorAction SilentlyContinue
    }

    foreach ($valueName in 'NoChangeStartMenu', 'NoSetTaskbar', 'NoStartMenuMorePrograms', 'NoStartMenuMFUprogramsList', 'NoFind', 'NoTrayContextMenu') {
        Remove-ItemProperty -Path $userPolicyKey -Name $valueName -ErrorAction SilentlyContinue
    }

    Get-Process -Name 'ServerManager' -ErrorAction SilentlyContinue | Stop-Process -Force
    Write-DesktopLog 'Stopped ServerManager and removed aggressive shell restrictions for non-admin session.'

    while (Get-Process -Name 'RDPWin' -ErrorAction SilentlyContinue) {
        Start-Sleep -Seconds 2
    }

    Write-DesktopLog 'RDPWin exited; logging off session.'
    shutdown.exe /l /f
}
catch {
    Write-DesktopLog "Unhandled error: $($_.Exception.Message)"
    shutdown.exe /l /f
    exit 1
}
'@

Set-Content -Path $launcherPath -Value $launcherScript -Encoding ASCII

New-ItemProperty -Path $runKey `
    -Name 'RDPWinDesktopLauncher' `
    -PropertyType String `
    -Value "PowerShell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$launcherPath`"" `
    -Force | Out-Null

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
cmd /c reg query "HKLM\SOFTWARE\Microsoft\ServerManager" /v DoNotOpenServerManagerAtLogon
cmd /c reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fResetBroken
cmd /c reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v MaxDisconnectionTime
cmd /c reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v RDPWinDesktopLauncher
