[CmdletBinding()]
param(
    [ValidateSet('Baseline', 'AfterActian', 'AfterRDPWinInstall', 'AfterConfig', 'LaunchSmoke', 'AdHoc')]
    [string]$Phase = 'AdHoc',

    [string]$OutputRoot = 'C:\Temp\RDPWinLab',

    [string]$RDPWinRoot = 'C:\ProgramData\ResortDataProcessing\RDPWin',

    [string]$RDPWinExe = 'C:\ProgramData\ResortDataProcessing\RDPWin\RDPWin5Client\RDPWin.exe',

    [string[]]$TargetHosts = @('DB01', 'DB02'),

    [int[]]$TargetPorts = @(135, 139, 445, 1583, 3351),

    [string[]]$SharePaths = @(),

    [string[]]$InstallerPaths = @(),

    [int]$MonitorRDPWinSeconds = 0,

    [switch]$CollectConfigText
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$computerName = $env:COMPUTERNAME
$outputDirectory = Join-Path -Path (Join-Path -Path $OutputRoot -ChildPath $computerName) -ChildPath "${Phase}_${timestamp}"
New-Item -Path $outputDirectory -ItemType Directory -Force | Out-Null

$collectors = New-Object System.Collections.Generic.List[object]

function Add-CollectorResult {
    param(
        [string]$Name,
        [bool]$Success,
        [string]$Detail = ''
    )

    $collectors.Add([pscustomobject]@{
        Name = $Name
        Success = $Success
        Detail = $Detail
    }) | Out-Null
}

function Write-JsonFile {
    param(
        [string]$FileName,
        [object]$InputObject,
        [int]$Depth = 5
    )

    $path = Join-Path -Path $outputDirectory -ChildPath $FileName
    $InputObject | ConvertTo-Json -Depth $Depth | Out-File -FilePath $path -Encoding UTF8
}

function Write-CsvFile {
    param(
        [string]$FileName,
        [object[]]$InputObject
    )

    $path = Join-Path -Path $outputDirectory -ChildPath $FileName
    if ($null -eq $InputObject -or $InputObject.Count -eq 0) {
        Set-Content -Path $path -Value '' -Encoding UTF8
        return
    }

    $InputObject | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
}

function Get-CurrentUserLabel {
    try {
        return [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    }
    catch {
        if ($env:USERDOMAIN -and $env:USERNAME) {
            return ("{0}\{1}" -f $env:USERDOMAIN, $env:USERNAME)
        }

        if ($env:USERNAME) {
            return $env:USERNAME
        }

        return $env:USER
    }
}

function Get-ObjectPropertyValue {
    param(
        [object]$InputObject,
        [string]$Name
    )

    if ($null -ne $InputObject -and $InputObject.PSObject.Properties[$Name]) {
        return $InputObject.PSObject.Properties[$Name].Value
    }

    return $null
}

function Invoke-Collector {
    param(
        [string]$Name,
        [scriptblock]$ScriptBlock
    )

    try {
        & $ScriptBlock
        Add-CollectorResult -Name $Name -Success $true
    }
    catch {
        Add-CollectorResult -Name $Name -Success $false -Detail $_.Exception.Message
        Write-JsonFile -FileName ("error_{0}.json" -f $Name) -InputObject ([pscustomobject]@{
            Collector = $Name
            Message = $_.Exception.Message
            Error = $_.ToString()
        }) -Depth 5
    }
}

function Get-RegistryValues {
    param([string]$Path)

    if (-not (Test-Path -Path $Path)) {
        return $null
    }

    $item = Get-ItemProperty -Path $Path
    $result = [ordered]@{}
    foreach ($property in $item.PSObject.Properties) {
        if ($property.Name -like 'PS*') {
            continue
        }

        $result[$property.Name] = $property.Value
    }

    [pscustomobject]$result
}

function Get-InstallEntries {
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    foreach ($root in $roots) {
        Get-ItemProperty -Path $root -ErrorAction SilentlyContinue |
            Where-Object {
                $name = Get-ObjectPropertyValue -InputObject $_ -Name 'DisplayName'
                $publisher = Get-ObjectPropertyValue -InputObject $_ -Name 'Publisher'
                ($name -match 'RDPWin|Resort|Actian|Zen|Pervasive|PSQL|Crystal|WebView2') -or
                ($publisher -match 'Resort|Actian|Pervasive')
            } |
            ForEach-Object {
                [pscustomobject]@{
                    RegistryRoot    = $root
                    DisplayName     = Get-ObjectPropertyValue -InputObject $_ -Name 'DisplayName'
                    DisplayVersion  = Get-ObjectPropertyValue -InputObject $_ -Name 'DisplayVersion'
                    Publisher       = Get-ObjectPropertyValue -InputObject $_ -Name 'Publisher'
                    InstallDate     = Get-ObjectPropertyValue -InputObject $_ -Name 'InstallDate'
                    InstallLocation = Get-ObjectPropertyValue -InputObject $_ -Name 'InstallLocation'
                    UninstallString = Get-ObjectPropertyValue -InputObject $_ -Name 'UninstallString'
                    PSChildName     = Get-ObjectPropertyValue -InputObject $_ -Name 'PSChildName'
                }
            }
    }
}

function Get-OdbcEntries {
    $paths = @(
        'HKLM:\SOFTWARE\ODBC\ODBCINST.INI\ODBC Drivers',
        'HKLM:\SOFTWARE\WOW6432Node\ODBC\ODBCINST.INI\ODBC Drivers',
        'HKLM:\SOFTWARE\ODBC\ODBC.INI\ODBC Data Sources',
        'HKLM:\SOFTWARE\WOW6432Node\ODBC\ODBC.INI\ODBC Data Sources'
    )

    foreach ($path in $paths) {
        $values = Get-RegistryValues -Path $path
        if ($null -eq $values) {
            continue
        }

        foreach ($property in $values.PSObject.Properties) {
            [pscustomobject]@{
                RegistryPath = $path
                Name = $property.Name
                Value = $property.Value
            }
        }
    }
}

function Get-HostResolution {
    foreach ($hostName in $TargetHosts) {
        try {
            $addresses = Resolve-DnsName -Name $hostName -ErrorAction Stop |
                Where-Object { $_.IPAddress } |
                Select-Object -ExpandProperty IPAddress

            [pscustomobject]@{
                HostName = $hostName
                Success = $true
                IPAddress = ($addresses -join ';')
                Error = ''
            }
        }
        catch {
            [pscustomobject]@{
                HostName = $hostName
                Success = $false
                IPAddress = ''
                Error = $_.Exception.Message
            }
        }
    }
}

function Get-PortTests {
    if (-not (Get-Command -Name Test-NetConnection -ErrorAction SilentlyContinue)) {
        foreach ($hostName in $TargetHosts) {
            foreach ($port in $TargetPorts) {
                [pscustomobject]@{
                    HostName = $hostName
                    Port = $port
                    TcpTestSucceeded = $false
                    Error = 'Test-NetConnection is not available.'
                }
            }
        }

        return
    }

    foreach ($hostName in $TargetHosts) {
        foreach ($port in $TargetPorts) {
            $result = Test-NetConnection -ComputerName $hostName -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue
            [pscustomobject]@{
                HostName = $hostName
                Port = $port
                TcpTestSucceeded = [bool]$result
                Error = ''
            }
        }
    }
}

function Get-ShareTests {
    foreach ($sharePath in $SharePaths) {
        [pscustomobject]@{
            Path = $sharePath
            Exists = Test-Path -Path $sharePath
        }
    }
}

function Get-InstallerInventory {
    foreach ($installerPath in $InstallerPaths) {
        $exists = Test-Path -Path $installerPath
        $item = if ($exists) { Get-Item -Path $installerPath } else { $null }
        $hash = if ($exists -and -not $item.PSIsContainer) { (Get-FileHash -Path $installerPath -Algorithm SHA256).Hash } else { '' }

        [pscustomobject]@{
            Path = $installerPath
            Exists = $exists
            LengthKB = if ($item -and -not $item.PSIsContainer) { [math]::Round($item.Length / 1KB, 2) } else { $null }
            LastWriteTime = if ($item) { $item.LastWriteTime } else { $null }
            Sha256 = $hash
        }
    }
}

function Get-RDPWinExeState {
    $exists = Test-Path -Path $RDPWinExe
    if (-not $exists) {
        return [pscustomobject]@{
            Path = $RDPWinExe
            Exists = $false
            LengthKB = $null
            LastWriteTime = $null
            Sha256 = ''
            ProductVersion = ''
            FileVersion = ''
        }
    }

    $item = Get-Item -Path $RDPWinExe
    $versionInfo = $item.VersionInfo
    [pscustomobject]@{
        Path = $RDPWinExe
        Exists = $true
        LengthKB = [math]::Round($item.Length / 1KB, 2)
        LastWriteTime = $item.LastWriteTime
        Sha256 = (Get-FileHash -Path $RDPWinExe -Algorithm SHA256).Hash
        ProductVersion = $versionInfo.ProductVersion
        FileVersion = $versionInfo.FileVersion
    }
}

function Get-RDPWinFileInventory {
    if (-not (Test-Path -Path $RDPWinRoot)) {
        return @([pscustomobject]@{
            RootPath = $RDPWinRoot
            Exists = $false
            ItemType = ''
            RelativePath = ''
            LengthKB = $null
            LastWriteTime = $null
            Sha256 = ''
        })
    }

    $root = Get-Item -Path $RDPWinRoot
    Get-ChildItem -Path $RDPWinRoot -Force -Recurse -ErrorAction SilentlyContinue |
        Where-Object {
            $relative = $_.FullName.Substring($root.FullName.Length).TrimStart('\')
            ($relative -notmatch '\\') -or ($relative -match '^RDPWin5Client\\[^\\]+$')
        } |
        Sort-Object FullName |
        Select-Object -First 700 |
        ForEach-Object {
            $hash = ''
            if (-not $_.PSIsContainer -and $_.Length -le 20MB) {
                try {
                    $hash = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
                }
                catch {
                    $hash = ''
                }
            }

            [pscustomobject]@{
                RootPath = $RDPWinRoot
                Exists = $true
                ItemType = if ($_.PSIsContainer) { 'Directory' } else { 'File' }
                RelativePath = $_.FullName.Substring($root.FullName.Length).TrimStart('\')
                LengthKB = if ($_.PSIsContainer) { $null } else { [math]::Round($_.Length / 1KB, 2) }
                LastWriteTime = $_.LastWriteTime
                Sha256 = $hash
            }
        }
}

function Get-RDPWinConfigCandidates {
    if (-not (Test-Path -Path $RDPWinRoot)) {
        return @()
    }

    $root = Get-Item -Path $RDPWinRoot
    $namePattern = 'GroupToServer|RDPWinPath|\.config$|\.ini$|\.xml$|\.json$|\.txt$|\.dsn$|\.udl$'

    Get-ChildItem -Path $RDPWinRoot -Force -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $relative = $_.FullName.Substring($root.FullName.Length).TrimStart('\')
            ($relative -notmatch '\\[^\\]+\\') -and
            ($_.Name -match $namePattern)
        } |
        Sort-Object FullName |
        Select-Object -First 200 |
        ForEach-Object {
            [pscustomobject]@{
                RelativePath = $_.FullName.Substring($root.FullName.Length).TrimStart('\')
                LengthKB = [math]::Round($_.Length / 1KB, 2)
                LastWriteTime = $_.LastWriteTime
                Sha256 = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
            }
        }
}

function Get-RedactedText {
    param([string]$Path)

    $text = Get-Content -Path $Path -Raw -ErrorAction Stop
    $text = $text -replace '(?i)(password|passwd|pwd|secret|token|apikey|api_key)\s*[:=]\s*[^;\r\n]+', '$1=<redacted>'
    $text
}

function Get-ConfigText {
    if (-not $CollectConfigText -or -not (Test-Path -Path $RDPWinRoot)) {
        return @()
    }

    $allowList = @('GroupToServer5.txt', 'RDPWinPath5.txt')
    foreach ($name in $allowList) {
        $path = Join-Path -Path $RDPWinRoot -ChildPath $name
        if (Test-Path -Path $path) {
            [pscustomobject]@{
                RelativePath = $name
                Text = Get-RedactedText -Path $path
            }
        }
    }
}

function Get-RDPWinProcesses {
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -match 'RDPWin|RDPWinInterface|RDP' } |
        Select-Object ProcessName, Id, StartTime, Path, MainWindowTitle, CPU, WorkingSet64
}

function Get-RecentlyChangedRDPWinFiles {
    if (-not (Test-Path -Path $RDPWinRoot)) {
        return @()
    }

    $root = Get-Item -Path $RDPWinRoot
    $cutoff = (Get-Date).AddDays(-7)
    Get-ChildItem -Path $RDPWinRoot -Force -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $cutoff } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 200 |
        ForEach-Object {
            [pscustomobject]@{
                RelativePath = $_.FullName.Substring($root.FullName.Length).TrimStart('\')
                LengthKB = [math]::Round($_.Length / 1KB, 2)
                LastWriteTime = $_.LastWriteTime
            }
        }
}

function Get-RDPWinLogCandidates {
    $candidateRoots = New-Object System.Collections.Generic.List[string]
    $candidateRoots.Add($RDPWinRoot) | Out-Null

    if ($env:ProgramData) {
        $candidateRoots.Add((Join-Path -Path $env:ProgramData -ChildPath 'ResortDataProcessing')) | Out-Null
    }

    if ($env:LOCALAPPDATA) {
        $candidateRoots.Add((Join-Path -Path $env:LOCALAPPDATA -ChildPath 'ResortDataProcessing')) | Out-Null
    }

    $roots = $candidateRoots | Where-Object { $_ -and (Test-Path -Path $_) } | Select-Object -Unique

    foreach ($rootPath in $roots) {
        $root = Get-Item -Path $rootPath
        Get-ChildItem -Path $rootPath -Force -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                ($_.Name -match '\.(log|trace|err|txt)$') -and
                (($_.FullName -match 'RDPWin|ResortDataProcessing|Actian|Zen|Pervasive') -or ($_.LastWriteTime -gt (Get-Date).AddHours(-6)))
            } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 120 |
            ForEach-Object {
                [pscustomobject]@{
                    SearchRoot = $rootPath
                    RelativePath = $_.FullName.Substring($root.FullName.Length).TrimStart('\')
                    LengthKB = [math]::Round($_.Length / 1KB, 2)
                    LastWriteTime = $_.LastWriteTime
                }
            }
    }
}

function Get-RelevantTcpConnections {
    if (-not (Get-Command -Name Get-NetTCPConnection -ErrorAction SilentlyContinue)) {
        return @()
    }

    $targetIps = New-Object System.Collections.Generic.HashSet[string]
    foreach ($hostName in $TargetHosts) {
        try {
            Resolve-DnsName -Name $hostName -ErrorAction Stop |
                Where-Object { $_.IPAddress } |
                ForEach-Object { [void]$targetIps.Add($_.IPAddress) }
        }
        catch {
        }
    }

    Get-NetTCPConnection -ErrorAction SilentlyContinue |
        Where-Object {
            $targetIps.Contains($_.RemoteAddress) -or
            ($TargetPorts -contains $_.RemotePort) -or
            ($TargetPorts -contains $_.LocalPort)
        } |
        Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess, CreationTime
}

Invoke-Collector -Name 'summary' -ScriptBlock {
    Write-JsonFile -FileName '00_summary.json' -InputObject ([pscustomobject]@{
        AssessmentType = 'RDPWinLabProbe'
        Phase = $Phase
        CollectedAt = Get-Date
        ComputerName = $computerName
        UserName = Get-CurrentUserLabel
        OutputDirectory = $outputDirectory
        RDPWinRoot = $RDPWinRoot
        RDPWinExe = $RDPWinExe
        TargetHosts = $TargetHosts
        TargetPorts = $TargetPorts
        SharePaths = $SharePaths
        InstallerPaths = $InstallerPaths
        CollectConfigText = [bool]$CollectConfigText
        MonitorRDPWinSeconds = $MonitorRDPWinSeconds
    }) -Depth 5
}

Invoke-Collector -Name 'host_context' -ScriptBlock {
    $computerInfo = if (Get-Command -Name Get-ComputerInfo -ErrorAction SilentlyContinue) {
        Get-ComputerInfo -ErrorAction SilentlyContinue
    } else {
        [pscustomobject]@{}
    }

    $computerSystem = if (Get-Command -Name Get-CimInstance -ErrorAction SilentlyContinue) {
        Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
    } else {
        [pscustomobject]@{}
    }

    $ipConfiguration = if (Get-Command -Name Get-NetIPConfiguration -ErrorAction SilentlyContinue) {
        Get-NetIPConfiguration | Select-Object InterfaceAlias, InterfaceDescription, IPv4Address, IPv4DefaultGateway, DNSServer
    } else {
        @()
    }

    Write-JsonFile -FileName '01_host_context.json' -InputObject ([pscustomobject]@{
        ComputerName = $computerName
        Domain = Get-ObjectPropertyValue -InputObject $computerSystem -Name 'Domain'
        PartOfDomain = Get-ObjectPropertyValue -InputObject $computerSystem -Name 'PartOfDomain'
        WindowsProductName = Get-ObjectPropertyValue -InputObject $computerInfo -Name 'WindowsProductName'
        WindowsVersion = Get-ObjectPropertyValue -InputObject $computerInfo -Name 'WindowsVersion'
        OsHardwareAbstractionLayer = Get-ObjectPropertyValue -InputObject $computerInfo -Name 'OsHardwareAbstractionLayer'
        CsTotalPhysicalMemory = Get-ObjectPropertyValue -InputObject $computerInfo -Name 'CsTotalPhysicalMemory'
        TimeZone = (Get-TimeZone).Id
        IPConfiguration = $ipConfiguration
    }) -Depth 8
}

Invoke-Collector -Name 'installed_software' -ScriptBlock {
    Write-CsvFile -FileName '02_installed_software_relevant.csv' -InputObject @(Get-InstallEntries)
}

Invoke-Collector -Name 'services' -ScriptBlock {
    $services = if (Get-Command -Name Get-Service -ErrorAction SilentlyContinue) {
        Get-Service |
        Where-Object { $_.Name -match 'actian|zen|psql|pervasive|rdpwin' -or $_.DisplayName -match 'actian|zen|psql|pervasive|rdpwin' } |
        Select-Object Name, DisplayName, Status, StartType
    } else {
        @()
    }

    Write-CsvFile -FileName '03_services_relevant.csv' -InputObject @($services)
}

Invoke-Collector -Name 'odbc' -ScriptBlock {
    Write-CsvFile -FileName '04_odbc_registry.csv' -InputObject @(Get-OdbcEntries)
}

Invoke-Collector -Name 'dns' -ScriptBlock {
    Write-CsvFile -FileName '05_dns_resolution.csv' -InputObject @(Get-HostResolution)
}

Invoke-Collector -Name 'ports' -ScriptBlock {
    Write-CsvFile -FileName '06_port_tests.csv' -InputObject @(Get-PortTests)
}

Invoke-Collector -Name 'shares' -ScriptBlock {
    Write-CsvFile -FileName '07_share_tests.csv' -InputObject @(Get-ShareTests)
}

Invoke-Collector -Name 'rdpwin_inventory' -ScriptBlock {
    Write-CsvFile -FileName '08_rdpwin_file_inventory.csv' -InputObject @(Get-RDPWinFileInventory)
    Write-JsonFile -FileName '08a_rdpwin_exe_state.json' -InputObject (Get-RDPWinExeState) -Depth 4
    Write-CsvFile -FileName '08b_installer_inventory_optional.csv' -InputObject @(Get-InstallerInventory)
}

Invoke-Collector -Name 'rdpwin_config_candidates' -ScriptBlock {
    Write-CsvFile -FileName '09_rdpwin_config_candidates.csv' -InputObject @(Get-RDPWinConfigCandidates)
    Write-JsonFile -FileName '10_rdpwin_config_text_optional.json' -InputObject @(Get-ConfigText) -Depth 4
}

Invoke-Collector -Name 'processes_before' -ScriptBlock {
    Write-CsvFile -FileName '11_processes_before.csv' -InputObject @(Get-RDPWinProcesses)
    Write-CsvFile -FileName '11a_tcp_connections_before.csv' -InputObject @(Get-RelevantTcpConnections)
}

if ($MonitorRDPWinSeconds -gt 0) {
    Invoke-Collector -Name 'process_monitor' -ScriptBlock {
        $samples = New-Object System.Collections.Generic.List[object]
        $end = (Get-Date).AddSeconds($MonitorRDPWinSeconds)

        while ((Get-Date) -lt $end) {
            $processes = @(Get-RDPWinProcesses)
            foreach ($process in $processes) {
                $samples.Add([pscustomobject]@{
                    SampleTime = Get-Date
                    ProcessName = $process.ProcessName
                    Id = $process.Id
                    StartTime = $process.StartTime
                    Path = $process.Path
                    MainWindowTitle = $process.MainWindowTitle
                    CPU = $process.CPU
                    WorkingSet64 = $process.WorkingSet64
                }) | Out-Null
            }

            Start-Sleep -Seconds 5
        }

        Write-CsvFile -FileName '12_rdpwin_process_monitor.csv' -InputObject $samples.ToArray()
    }
}

Invoke-Collector -Name 'processes_after' -ScriptBlock {
    Write-CsvFile -FileName '13_processes_after.csv' -InputObject @(Get-RDPWinProcesses)
    Write-CsvFile -FileName '13a_tcp_connections_after.csv' -InputObject @(Get-RelevantTcpConnections)
}

Invoke-Collector -Name 'recent_files' -ScriptBlock {
    Write-CsvFile -FileName '14_rdpwin_recent_files.csv' -InputObject @(Get-RecentlyChangedRDPWinFiles)
}

Invoke-Collector -Name 'log_candidates' -ScriptBlock {
    Write-CsvFile -FileName '15_log_candidates.csv' -InputObject @(Get-RDPWinLogCandidates)
}

Write-CsvFile -FileName '99_collectors.csv' -InputObject $collectors.ToArray()

Write-Host "RDPWin lab probe complete."
Write-Host "OutputDirectory: $outputDirectory"
