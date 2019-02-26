function Connect-BTSCatalog {
    [CmdletBinding()]
    [OutputType([Microsoft.BizTalk.ExplorerOM.BtsCatalogExplorer])]
    Param (
        [Parameter()]
        [string]$Server = $env:COMPUTERNAME,
        [Parameter()]
        [string]$SQLInstance,
        [Parameter()]
        [string]$ManagementDB
    )
    Process {        
        #Calculate BizTalk connection string
        $wmi = Get-WmiObject -Class MSBTS_GroupSetting -Namespace root\MicrosoftBizTalkServer -ComputerName $server -ErrorAction Stop
        if (-not $SQLInstance) {
            $SQLInstance = $wmi.MgmtDbServerName
        }
        if (-not $ManagementDB) {
            $ManagementDB = $wmi.MgmtDbName
        }

        $btsCatalog = New-Object "Microsoft.BizTalk.ExplorerOM.BtsCatalogExplorer"
        $btsCatalog.ConnectionString = "SERVER=$SQLInstance;DATABASE=$ManagementDB;Integrated Security=SSPI"

        return $btsCatalog
    }
}