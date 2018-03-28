function Clean-BTDFEnvironment {
    [CmdletBinding()]
    Param (
        [Parameter(HelpMessage="Valid parameters are Debug, Release and Server. Defaults to Debug")]
        [ValidateSet("Debug", "Release", "Server")]
        [string]$Configuration = "Debug",

        [Parameter(HelpMessage="Terminate instances related to deployed app")]
        [switch]$TerminateInstances
    )
    DynamicParam {
        $btsCatalog.Refresh()
        $btsApps = $btsCatalog.Applications | Select-Object -Property Name,$projectPathColumn | Where-Object {$_.ProjectPath}

        $paramDict = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        #region DeployBTMgmtDB
        if ($Configuration -eq "Server") {
            $attributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $parameter = New-Object System.Management.Automation.ParameterAttribute
            $parameter.HelpMessage = "Register artifacts in BizTalk DB"
            $attributeCollection.Add($parameter)
            $deployBTMgmtDBParameter = New-Object System.Management.Automation.RuntimeDefinedParameter("DeployBTMgmtDB", [switch], $attributeCollection)
            $paramDict.Add("DeployBTMgmtDB", $deployBTMgmtDBParameter)
        }
        #endregion

        #region Exemptions
        $attributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $parameter = New-Object System.Management.Automation.ParameterAttribute
        $attributeCollection.Add($parameter)
        $validateSet = New-Object System.Management.Automation.ValidateSetAttribute($btsApps | Select-Object -ExpandProperty Name)
        $attributeCollection.Add($validateSet)
        $exemptionsParameter = New-Object System.Management.Automation.RuntimeDefinedParameter("Exemptions", [string[]], $attributeCollection)
        $exemptionsParameter.Value = @()
        $paramDict.Add("Exemptions", $exemptionsParameter)
        #endregion

        return $paramDict
    }
    Process {
        $cleanParams = @{}
        if ($PSBoundParameters.ContainsKey("DeployBTMgmtDB")) {
            $cleanParams["DeployBTMgmtDB"] = $DeployBTMgmtDB
        }
        if ($PSBoundParameters.ContainsKey("TerminateInstances")) {
            $cleanParams["TerminateInstances"] = $TerminateInstances
        }
        
        foreach ($a in $btsApps) {
            $btsCatalog.Refresh()
            if (-not $btsCatalog.Applications[$a.Name]) {
                Write-Warning "$($a.Name) already removed"
                
            } elseif ($PSBoundParameters["Exemptions"].Contains($a.Name)) {
                Write-Information "$($a.Name) exempt"
            } else {
                Write-Information "Removing $($a.Name)"
                Deploy-BTDFApplication -ProjectPath $a.ProjectPath `
                    -DeploymentType Undeploy `
                    -Configuration $Configuration
            }
        }
    }
}