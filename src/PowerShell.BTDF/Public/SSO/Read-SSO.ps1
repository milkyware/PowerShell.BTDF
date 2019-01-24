#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Read BTDF SSO settings for deployed BizTalk applications

.DESCRIPTION
    Makes use of BTDF SSOSettingsFileReader helper assembly to read all SSO settings for a deployed application

.PARAMETER Application
    Name of the BTDF deployed application to read SSO settings

.EXAMPLE
    PS C:\> Read-SSO -Application Scratchpad
    Returns a hashtable of SSO settings for the Scratchpad application

.OUTPUTS
    Hashtable
#>

function Read-SSO {
    [CmdletBinding()]
    [OutputType([hashtable])]
    Param (
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [string]$Application
    )
    Process {
        return [SSOSettingsFileReader]::Read($Application)
    }
}