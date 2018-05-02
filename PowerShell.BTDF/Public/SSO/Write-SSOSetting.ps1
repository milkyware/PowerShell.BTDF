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