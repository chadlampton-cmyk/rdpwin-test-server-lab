[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ManifestPath = "$PSScriptRoot\..\config\dbtest01-layout.json",
    [string]$RootPath,
    [switch]$CreateShares,
    [string[]]$ShareReadAccess = @(),
    [string[]]$ShareChangeAccess = @(),
    [string[]]$ShareFullAccess = @('Administrators')
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -Path $ManifestPath)) {
    throw "Manifest not found: $ManifestPath"
}

$manifest = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json
$effectiveRootPath = if ($PSBoundParameters.ContainsKey('RootPath') -and $RootPath) { $RootPath } else { $manifest.rootPath }

if (-not $effectiveRootPath) {
    throw 'No root path was provided and the manifest does not define one.'
}

function Resolve-LayoutPath {
    param(
        [string]$BasePath,
        [string]$RelativePath
    )

    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        return $RelativePath
    }

    return Join-Path -Path $BasePath -ChildPath $RelativePath
}

Write-Host ("DB server layout manifest: {0}" -f $ManifestPath)
Write-Host ("Server name: {0}" -f $manifest.serverName)
Write-Host ("Root path: {0}" -f $effectiveRootPath)

foreach ($folder in $manifest.folders) {
    $targetPath = Resolve-LayoutPath -BasePath $effectiveRootPath -RelativePath $folder.path
    if ($PSCmdlet.ShouldProcess($targetPath, 'Create directory')) {
        New-Item -Path $targetPath -ItemType Directory -Force | Out-Null
    }
}

if ($CreateShares) {
    if (-not (Get-Command -Name New-SmbShare -ErrorAction SilentlyContinue)) {
        throw 'New-SmbShare is not available on this host.'
    }

    foreach ($share in $manifest.shares) {
        $sharePath = Resolve-LayoutPath -BasePath $effectiveRootPath -RelativePath $share.path
        $existingShare = Get-SmbShare -Name $share.name -ErrorAction SilentlyContinue

        if ($existingShare) {
            Write-Host ("Share already exists: {0} -> {1}" -f $share.name, $existingShare.Path)
            continue
        }

        $shareParams = @{
            Name        = $share.name
            Path        = $sharePath
            Description = $share.description
            FullAccess  = $ShareFullAccess
        }

        if ($ShareReadAccess.Count -gt 0) {
            $shareParams['ReadAccess'] = $ShareReadAccess
        }

        if ($ShareChangeAccess.Count -gt 0) {
            $shareParams['ChangeAccess'] = $ShareChangeAccess
        }

        if ($PSCmdlet.ShouldProcess($share.name, "Create SMB share at $sharePath")) {
            New-SmbShare @shareParams | Out-Null
        }
    }
}

Write-Host 'DBTEST01 layout creation complete.'
