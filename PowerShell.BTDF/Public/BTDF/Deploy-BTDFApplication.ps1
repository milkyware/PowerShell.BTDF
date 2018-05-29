#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Deploys a BTDF based BizTalk application

.DESCRIPTION
    Deploys a BTDF based BizTalk application and allows configuration to support multi-server setups (Deploying resources to secondary nodes and registering application on primary node). This also uses BizTalk types to check if an upgraded application is a dependency and will strip and restore this application recursively and in order. Supports both local (Debug/Release) deployments as well as server deployments. The parameters are validated and may need adjusting should your environments be named differently

.PARAMETER ProjectPath
    The path which the BTDF application is stored in (Eqivalent to the installation path/targetdir). Usually one level above the deployment folder for an application

.PARAMETER DeploymentType
    Choose whether to "Deploy", "Undeploy" or "Quick Deploy (UpdateOrchestration)" the BizTalk application (Default is "Deploy")

.PARAMETER Environment
    Select the environment to deploy. Must match what is configured in BTDF environmentsettings spreadsheet. Defaults to Local (Only applicable to Server deployments)

.PARAMETER DeployBTMgmtDB
    Registers application in BizTalk. Assemblies/components are GACed otherwise (Only applicable to Server deployments)

.PARAMETER SkipUnDeploy
    Skip undeploying application prior to deployment (Only applicable to Server deployments)

.PARAMETER SkipBizTalkRestart
    If supported by deployment project, skip restarting BizTalk Host instances post-deployment

.PARAMETER SkipIISRestart
    If supported by deployment project, skip IISReset post-deployment

.PARAMETER SkipApplicationStart
    If supported by deployment project, don't start application after deployment

.PARAMETER TerminateInstances
    If supported by deployment project, terminate running/suspended instances

.PARAMETER SkipRestore
    Skips restoring dependant applciations, if any

.EXAMPLE
    Deploy application components/assemblies

    C:\PS> Deploy-BTDFApplication -ProjectPath "C:\Program Files (x86)\Scratchpad"

.EXAMPLE
    Deploy application and register in BizTalk

    C:\PS> Deploy-BTDFApplication -ProjectPath "C:\Program Files (x86)\Scratchpad" -Configuration Server -DeployBTMgmtDB

.EXAMPLE
    Deploy application and register in BizTalk with live environment settings

    C:\PS> Deploy-BTDFApplication -ProjectPath "C:\Program Files (x86)\Scratchpad" -Configuration Server -Environment Prod -DeployBTMgmtDB

.EXAMPLE
    Undeploys application and removes from BizTalk

    C:\PS> Deploy-BTDFApplication -ProjectPath "C:\Program Files (x86)\Scratchpad" -DeploymentType Undeploy -Configuration Server -DeployBTMgmtDB

.NOTES
    General notes
#>

function Deploy-BTDFApplication {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([hashtable])]
    Param (
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, HelpMessage="Path to the folder of the BizTalk app")]
        [System.IO.DirectoryInfo]$ProjectPath,

        [Parameter(HelpMessage="Defaults to Deploy")]
        [ValidateSet("Deploy", "DeployBAM", "DeployBRE", "DeploySSO", "Installer",  "QuickDeploy", "Undeploy", "UndeployBAM", "UndeployBRE")]
        [string]$DeploymentType = "Deploy",

        [Parameter(HelpMessage="Valid parameters are Debug, Release and Server. Defaults to Debug")]
        [ValidateSet("Debug", "Release", "Server")]
        [string]$Configuration = "Debug",

        [Parameter(HelpMessage="Valid parameters are Local, Dev , Int, UAT and Prod. Defaults to Local")]
        [ValidateSet("Local","Dev","Int","UAT","Train","Prod")]
        [string]$Environment = "Local",

        [Parameter(HelpMessage="Register artifacts in BizTalk DB")]
        [switch]$DeployBTMgmtDB,
  
        [Parameter(HelpMessage="Only deploy instead of redeploy")]
        [switch]$SkipUnDeploy,

        [Parameter(HelpMessage="Skip starting BizTalk hosts back up post deployment")]
        [switch]$SkipBizTalkRestart,

        [Parameter(HelpMessage="Skip IISReset post deployment")]
        [switch]$SkipIISRestart,

        [Parameter(HelpMessage="Skipping starting BizTalk app post deployment")]
        [switch]$SkipApplicationStart,

        [Parameter(HelpMessage="Terminate instances related to deployed app")]
        [switch]$TerminateInstances,

        [Parameter(HelpMessage="Skip restoring dependant applications")]
        [switch]$SkipRestore
    )
    Process {
        #region Parameter checks
        if ($Configuration -ne "Server") {
            if ($PSBoundParameters.ContainsKey("Environment")) {
                throw [System.ArgumentException]::new("Environment must be used with the `"Server`" configuration")
            }
            if ($PSBoundParameters.ContainsKey("DeployBTMgmtDB")) {
                throw [System.ArgumentException]::new("DeployBTMgmtDB must be used with the `"Server`" configuration")
            }
            if ($PSBoundParameters.ContainsKey("SkipUnDeploy")) {
                throw [System.ArgumentException]::new("SkipUnDeploy must be used with the `"Server`" configuration")
            }
        }
        #endregion

        #region Get properties from BTDF project
        $btdfProject = Join-Path -Path $ProjectPath -ChildPath "Deployment\Deployment.btdfproj"
        $btdfProjectXml = [xml](Get-Content -Path $btdfProject)
        $manufacturer = $btdfProjectXml.GetElementsByTagName("Manufacturer")."#text"
        Write-Debug "Manufacturer = $manufacturer"
        $projectName = $btdfProjectXml.GetElementsByTagName("ProjectName")."#text"
        Write-Debug "ProjectName = $projectName"
        #endregion

        #region Get back referenced applications
        $btsCatalog.Refresh()
        $btsApp = $btsCatalog.Applications["$projectName"]
        Write-Verbose "Checking back references for $projectName"
        try {
            if ((-not ($Configuration -eq "Server" -and -not $DeployBTMgmtDB)) `
                -and ($btsApp -ne $null) `
                -and ($DeploymentType -in "Deploy","UnDeploy")) {
                if ($backRefs -eq $null) {
                    Write-Verbose "Creating new back refs stack"
                    $backRefs = [System.Collections.Generic.Stack[System.Object]]::new()
                }
    
                $btsApps = $btsCatalog.Applications["$projectName"].BackReferences | Select-Object -Property Name,$projectPathColumn
                foreach ($a in $btsApps) {
                    $btsCatalog.Refresh()
                    if ($btsCatalog.Applications[$a.Name]) {
                        $backRefs.Push($a)
                        Write-Verbose "Removing back reference: $($a.Name)"
                        Write-Debug "BizTalk App: $($a.Name) = $($a.ProjectPath)"

                        $undeployParams = $PSBoundParameters
                        $undeployParams["ProjectPath"] = $a.ProjectPath
                        $undeployParams["DeploymentType"] = "Undeploy"
                        Deploy-BTDFApplication @undeployParams
                    }
                    else {
                        Write-Warning "$($a.Name) already removed"
                    }
                }
                if (($backRefs.Count -gt 0) -and ($btsApps.Count -gt 0)) {
                    Write-Debug ($backRefs.GetEnumerator() | Out-String)
                }
            }
            else {
                Write-Verbose "No back references"
            }
            $backRefsRemoved = $true
        }
        catch {
            Write-Error -Message "Undeploying back references failed" -ErrorAction Continue
            Write-Error "$_" -ErrorAction Continue
        }
        #endregion

        #region Calculate deployment variables
        #Calculate required properties
        $deployment = (Get-ChildItem -Path $ProjectPath -Filter *Deployment)[0]
        Write-Debug "Deployment = $($deployment.FullName)"
        $results = New-Item -Path $ProjectPath -Name "DeployResults\DeployResults.txt" -ItemType File -Force
        Write-Debug "Results = $results"

        #Get/Create project registry keys
        $manufacturerReg = if ($softwareReg32 | Join-Path -ChildPath $manufacturer | Test-Path) {
            $softwareReg32 | Join-Path -ChildPath $manufacturer | Get-Item
        } else {
            New-Item -Path $softwareReg32.PSPath -Name $manufacturer
            Write-Verbose "Created manufacturer key: $manufacturer"
        }

        $projectReg = if ($manufacturerReg | Join-Path -ChildPath $projectName | Test-Path) {
            $manufacturerReg | Join-Path -ChildPath $projectName | Get-Item
        } else {
            New-Item -Path $manufacturerReg.PSPath -Name $projectName
            Write-Verbose "Created project key: $projectName"
        }
        
        #Get properties from Application BTDF registry
        try {
            $version = $projectReg.GetValue("InstalledVersion")
            if (-not $version) {
                throw
            }
            Write-Debug "Version = $version"
        }
        catch {
            Write-Warning "Unable to find version"
        }
        #endregion

        #region Run EnvironmentSettingsExporter
        if (($DeploymentType -eq "Deploy") -and ($Configuration -eq "Server")) {
            $envSettingsDir = $deployment | Join-Path -ChildPath "EnvironmentSettings" | Get-Item
            Write-Debug "Environment Settings Dir = $($envSettingsDir.FullName)"

            $settingsExporter = Join-Path -Path $deployment.FullName -ChildPath "Framework\DeployTools\EnvironmentSettingsExporter.exe"
            Write-Debug "Settings Exporter = $settingsExporter"
            Invoke-Process -FilePath $settingsExporter `
                -ArgumentList "`"$(Join-Path -Path $envSettingsDir.FullName -ChildPath \SettingsFileGenerator.xml)`"",
                    "`"$($envSettingsDir.FullName)`"" | Out-Null
            $envSettings = Join-Path -Path $envSettingsDir -ChildPath "Exported_$Environment`Settings.xml" | Get-Item
            Write-Debug "Environment Settings = $($envSettings.FullName)"
        }
        #endregion

        #region Run MSBuild and deploy
        if ($backRefsRemoved) {
            $projectReg | New-ItemProperty -Name "Configuration" -Value $Configuration -Force | Out-Null
            $projectReg | New-ItemProperty -Name "LastDeploySettingsFilePath" -Value $envSettings.FullName -Force | Out-Null
            $projectReg | New-ItemProperty -Name "Version" -Value $version -Force | Out-Null
            Write-Verbose "$($btdfTargets[$DeploymentType]["Message"]): $projectName"
            $msbuildArgs = "/t:$($btdfTargets[$DeploymentType]["Target"])",
                $(if ($version) {
                    "/p:ProductVersion=$version"
                }),
                $(if (($DeploymentType -eq "Deploy") -and ($Configuration -eq "Server")) {
                    "/p:ENV_SETTINGS=`"$($envSettings)`""
                }),
                $(if ($PSBoundParameters.ContainsKey("TerminateInstances")) {
                    "/p:AutoTerminateInstances=$TerminateInstances"
                }),
                $(if ($Configuration) {
                    "/p:Configuration=$Configuration"
                }),
                $(if ($Configuration -eq "Server") {
                    "/p:DeployBizTalkMgmtDB=$DeployBTMgmtDB"
                }),
                $(if ($PSBoundParameters.ContainsKey("SkipBizTalkRestart")) {
                    "/p:SkipHostInstancesRestart=$SkipBizTalkRestart"
                }),
                $(if ($PSBoundParameters.ContainsKey("SkipIISRestart")) {
                    "/p:SkipHostInstancesRestart=$SkipIISRestart"
                }),
                $(if ($PSBoundParameters.ContainsKey("SkipUnDeploy")) {
                    "/p:SkipHostInstancesRestart=$SkipUnDeploy"
                }),
                $(if ($PSBoundParameters.ContainsKey("SkipApplicationStart")) {
                    "/p:StartApplicationOnDeploy=$(-not $SkipApplicationStart)"
                }),
                "/l:FileLogger,Microsoft.Build.Engine;logfile=`"$results`""
            Invoke-MSBuild -Project $btdfProject `
                -ArgumentList $msbuildArgs `
                -Version 4.0 `
                -Run32Bit `
                -ErrorAction Stop
        }
        #endregion

        #region Restore back referenced applications in reverse
        if ($SkipRestore -and ($backRefs.Count -gt 0)) {
            Write-Verbose "Skipping restore"
        }

        if (($backRefs.Count -gt 0) -and ($DeploymentType -eq "Deploy") -and (-not $SkipRestore)) {
            Write-Debug "Back References Count = $($backRefs.Count)"
            while (($backRefs.Count -gt 0) -and ($DeploymentType -eq "Deploy")) {
                $app = $backRefs.Pop()
                Write-Verbose "Restoring: $($app.Name)"
                $deployParams = $PSBoundParameters
                $deployParams["ProjectPath"] = $app.ProjectPath
                $deployParams["DeploymentType"] = $DeploymentType
                $deployParams["Configuration"] = $Configuration
                Deploy-BTDFApplication @deployParams
            }
        }
        #endregion
    }
}