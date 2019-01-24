[CmdletBinding(SupportsShouldProcess=$true)]
Param (
    [Parameter(Mandatory = $true)]
    [string]$ApiKey,
    [Parameter()]
    [string]$Prerelease
)
Process {
    Install-PackageProvider -Name "Nuget" -Scope CurrentUser -MinimumVersion "2.8.5.201" -Force 
    Install-Module -Name Nuget, PackageManagement, PowerShellGet -Scope CurrentUser -Force

    Get-Module | Remove-Module -Force -ErrorAction SilentlyContinue

    Write-Verbose "Installing PowerShell modules"
    Import-Module -Name Nuget -MinimumVersion "1.3.3" -Force
    Import-Module -Name PackageManagement -MinimumVersion "1.2.4" -Force
    Import-Module -Name PowerShellGet -MinimumVersion "2.0.3" -Force
    Write-Verbose "PowerShell modules installed"

    # Get-Module | Group-Object -Property Name | Where-Object {$_.Count -gt 1} | Foreach-Object {$_ | Select-Object -ExpandProperty Group | Sort-Object -Property Version -Descending | Select-Object -Skip 1} | Remove-Module -Force

    Get-Module | Select-Object ModuleType, Version, Name, Path

    $manifests = Get-ChildItem -Path $PSScriptRoot -Recurse  *.psd1
    Write-Debug -Message "Manifests found: $($manifests.Count)"

    foreach ($m in $manifests) {
        Write-Debug "Manifest = $($m.Fullname)"
        Write-Verbose "Module found at $($m.FullName)"

        Write-Verbose "Updating manifest"
        Update-ModuleManifest -Path $m.FullName -Prerelease $Prerelease
        Write-Verbose "Updated manifest"

        Write-Verbose "Publishing module"
        Publish-Module -Path $m.Directory.FullName -NuGetApiKey $ApiKey -Force
        Write-Verbose "Published module"
    }
}