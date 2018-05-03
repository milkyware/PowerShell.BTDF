#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Write settings to BTDF SSO for deployed BizTalk applications

.DESCRIPTION
    Makes use of BTDF SSOSettingsFileReader helper assembly to read all SSO settings for a deployed application

.PARAMETER Application
    Name of the BTDF deployed application to read SSO settings

.PARAMETER Setting
    Name of the setting to write to. Will create the setting if it doesn't already exist

.PARAMETER Value
    Name of the SSO setting to get the value of

.EXAMPLE
    PS C:\> Write-SSOSetting -Application Scratchpad -Setting StringSetting -Value StringValue
    Returns a string typed value from SSO for the Scatchpad appliction for the setting "StringSetting"

.OUTPUTS
    string
#>

function Write-SSOSetting {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
        [string]$Application,
        [Parameter(Mandatory=$true, Position=1)]
        [string]$Setting,
        [Parameter(Mandatory=$true, Position=2)]
        [string]$Value
    )
    Process {
        [SSOSettingsFileManager.SSOSettingsManager]::WriteSetting($Application, $Setting, $Value)
    }
}