[CmdletBinding(SupportsShouldProcess=$true)]
Param (
    [Parameter(Mandatory=$true)]
    [ValidateScript({$_.Exists -and ($_.Extension -eq ".psd1")})]
    [System.IO.FileInfo]$Manifest,
    [Parameter(Mandatory = $true)]
    [string]$ApiKey,
    [Parameter()]
    [version]$Version = (Get-Date).ToString("yy.MM.dd"),
    [Parameter()]
    [string]$Prerelease = ""
)
Process {
    Write-Verbose "ApiKey = $ApiKey"
    Write-Verbose "Version = $Version"
    Write-Verbose "Prerelease = $Prerelease"

    Write-Verbose "Installing PowerShell modules"
    Install-PackageProvider -Name "Nuget" -Scope CurrentUser -MinimumVersion "2.8.5.201" -Force | Out-Null
    Install-Module -Name Nuget, PackageManagement, PowerShellGet -Scope CurrentUser -Force | Out-Null

    Import-Module -Name Nuget -MinimumVersion "1.3.3" -Force | Out-Null
    Import-Module -Name PackageManagement -MinimumVersion "1.2.4" -Force | Out-Null
    Import-Module -Name PowerShellGet -MinimumVersion "2.0.3" -Force | Out-Null
    Write-Verbose "PowerShell modules installed"

    Write-Verbose "Checking for duplicate versions of modules"
    Get-Module | Group-Object -Property Name | Where-Object {$_.Count -gt 1} | Foreach-Object {
        Write-Verbose "Found multiple versions of $($_.Name)"
        $_ | Select-Object -ExpandProperty Group | Sort-Object -Property Version -Descending | Select-Object -Skip 1
    } | Remove-Module -Force
    Get-Module | Select-Object ModuleType, Version, Name, Path

    Write-Verbose "Updating manifest"
    Update-ModuleManifest -Path $Manifest.FullName -ModuleVersion $Version -Prerelease $Prerelease
    Write-Verbose "Updated manifest"

    Write-Verbose "Publishing module"
    Publish-Module -Path $Manifest.Directory.FullName -NuGetApiKey $ApiKey -Force
    Write-Verbose "Published module"
}