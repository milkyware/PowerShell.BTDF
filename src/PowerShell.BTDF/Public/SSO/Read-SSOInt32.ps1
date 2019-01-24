#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Read BTDF SSO settings for deployed BizTalk applications

.DESCRIPTION
    Makes use of BTDF SSOSettingsFileReader helper assembly to read all SSO settings for a deployed application

.PARAMETER Application
    Name of the BTDF deployed application to read SSO settings

.PARAMETER Value
    Name of the SSO setting to get the value of

.EXAMPLE
    PS C:\> Read-SSO -Application Scratchpad -Value NumberSetting
    Returns a int typed value from SSO for the Scatchpad appliction for the setting "NumberSetting"

.OUTPUTS
    int
#>

function Read-SSOInt32 {
    [CmdletBinding()]
    [OutputType([int])]
    Param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
        [string]$Application,
        [Parameter(Mandatory=$true, Position=1)]
        [string]$Value
    )
    Process {
        return [SSOSettingsFileReader]::ReadInt32($Application, $Value)
    }
}