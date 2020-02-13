#Requires -RunAsAdministrator
#Requires -PSEdition Desktop

[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.BizTalk.ExplorerOM")
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.BizTalk.Operations")
[System.Reflection.Assembly]::LoadWithPartialName("SSOSettingsFileReader")

#region BTDF
function Clean-BTDFEnvironment
{
    [CmdletBinding()]
    Param (
        [Parameter(HelpMessage = "Valid parameters are Debug, Release and Server. Defaults to Debug")]
        [ValidateSet("Debug", "Release", "Server")]
        [string]$Configuration = "Debug",

        [Parameter(HelpMessage = "Terminate instances related to deployed app")]
        [switch]$TerminateInstances
    )
    DynamicParam
    {
        $btsCatalog.Refresh()
        $btsApps = $btsCatalog.Applications | Select-Object -Property Name, $projectPathColumn | Where-Object { $_.ProjectPath }

        $paramDict = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        #region DeployBTMgmtDB
        if ($Configuration -eq "Server")
        {
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
        $exemptionsParameter = New-Object System.Management.Automation.RuntimeDefinedParameter("Exemptions", [System.Collections.Generic.List[string]], $attributeCollection)
        $exemptionsParameter.Value = @()
        $paramDict.Add("Exemptions", $exemptionsParameter)
        $PSBoundParameters["Exemptions"] = [System.Collections.Generic.List[string]]::new()
        #endregion

        return $paramDict
    }
    Process
    {
        $cleanParams = @{ }
        if ($PSBoundParameters.ContainsKey("DeployBTMgmtDB"))
        {
            $cleanParams["DeployBTMgmtDB"] = $PSBoundParameters["DeployBTMgmtDB"]
        }
        if ($PSBoundParameters.ContainsKey("TerminateInstances"))
        {
            $cleanParams["TerminateInstances"] = $TerminateInstances
        }
        
        foreach ($a in $btsApps)
        {
            Write-Debug "App: $($a.Name)"
            $btsCatalog.Refresh()
            if (-not $btsCatalog.Applications[$a.Name])
            {
                Write-Warning "$($a.Name) already removed"
                
            } 
            elseif ($PSBoundParameters["Exemptions"].Contains($a.Name))
            {
                Write-Verbose "$($a.Name) exempt"
            } 
            else
            {
                Write-Information "Removing $($a.Name)"
                Deploy-BTDFApplication -ProjectPath $a.ProjectPath `
                    -DeploymentType Undeploy `
                    -Configuration $Configuration `
                    @cleanParams
            }
        }
    }
}

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
function Deploy-BTDFApplication
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([hashtable])]
    Param (
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true, HelpMessage = "Path to the folder of the BizTalk app")]
        [System.IO.DirectoryInfo[]]$ProjectPath,

        [Parameter(HelpMessage = "Defaults to Deploy")]
        [ValidateSet("BounceBizTalk", "Deploy", "DeployBAM", "DeployBRE", "DeploySSO", "Installer", "PreProcessBindings", "QuickDeploy", "Undeploy", "UndeployBAM", "UndeployBRE")]
        [string]$DeploymentType = "Deploy",

        [Parameter(HelpMessage = "Valid parameters are Debug, Release and Server. Defaults to Debug")]
        [ValidateSet("Debug", "Release", "Server")]
        [string]$Configuration = "Debug",

        [Parameter(HelpMessage = "Valid parameters are Local, Dev , Int, UAT and Prod. Defaults to Local")]
        [ValidateSet("Local", "Dev", "Int", "UAT", "Train", "Prod")]
        [string]$Environment = "Local",

        [Parameter(HelpMessage = "Register artifacts in BizTalk DB")]
        [switch]$DeployBTMgmtDB,
  
        [Parameter(HelpMessage = "Only deploy instead of redeploy")]
        [switch]$SkipUnDeploy,

        [Parameter(HelpMessage = "Skip starting BizTalk hosts back up post deployment")]
        [switch]$SkipBizTalkRestart,

        [Parameter(HelpMessage = "Skip IISReset post deployment")]
        [switch]$SkipIISRestart,

        [Parameter(HelpMessage = "Skipping starting BizTalk app post deployment")]
        [switch]$SkipApplicationStart,

        [Parameter(HelpMessage = "Terminate instances related to deployed app")]
        [switch]$TerminateInstances,

        [Parameter(HelpMessage = "Skip restoring dependant applications")]
        [switch]$SkipRestore
    )
    Process
    {
        #region Parameter checks
        if ($Configuration -ne "Server")
        {
            if ($PSBoundParameters.ContainsKey("Environment"))
            {
                throw [System.ArgumentException]::new("Environment must be used with the `"Server`" configuration")
            }
            if ($PSBoundParameters.ContainsKey("DeployBTMgmtDB"))
            {
                throw [System.ArgumentException]::new("DeployBTMgmtDB must be used with the `"Server`" configuration")
            }
            if ($PSBoundParameters.ContainsKey("SkipUnDeploy"))
            {
                throw [System.ArgumentException]::new("SkipUnDeploy must be used with the `"Server`" configuration")
            }
        }
        #endregion

        foreach ($pp in $ProjectPath)
        {
            Write-Debug "ProjectPath = $pp"

            #region Get properties from BTDF project
            $btdfProject = Join-Path -Path $pp -ChildPath "Deployment\Deployment.btdfproj"
            $btdfProjectXml = [xml](Get-Content -Path $btdfProject)
            $manufacturer = $btdfProjectXml.GetElementsByTagName("Manufacturer")."#text"
            Write-Debug "Manufacturer = $manufacturer"
            $projectName = $btdfProjectXml.GetElementsByTagName("ProjectName")."#text"
            Write-Debug "ProjectName = $projectName"
            #endregion

            #region Get back referenced applications
            $btsCatalog.Refresh()
            $btsApp = $btsCatalog.Applications["$projectName"]
            Write-Verbose "Checking back references for: $projectName"
            try
            {
                if ((-not ($Configuration -eq "Server" -and -not $DeployBTMgmtDB)) `
                        -and $btsApp `
                        -and ($DeploymentType -in "Deploy", "UnDeploy"))
                {
                    if (-not $backRefs)
                    {
                        Write-Verbose "Creating new back refs stack"
                        $backRefs = [System.Collections.Generic.Stack[System.Object]]::new()
                    }
    
                    $btsApps = $btsCatalog.Applications["$projectName"].BackReferences | Select-Object -Property Name, $projectPathColumn

                    if ($btsApps.Count -gt 0)
                    {
                        Write-Verbose "Back refs found"
                    }
                    foreach ($a in $btsApps)
                    {
                        $btsCatalog.Refresh()
                        if ($btsCatalog.Applications[$a.Name])
                        {
                            Write-Verbose "Removing back reference: $($a.Name)"
                            Write-Debug "BizTalk App: $($a.Name) = $($a.ProjectPath)"

                            $undeployParams = $PSBoundParameters
                            $undeployParams["ProjectPath"] = $a.ProjectPath
                            $undeployParams["DeploymentType"] = "Undeploy"

                            try
                            {
                                if ($PSCmdlet.ShouldProcess($a.Name, "Removing BizTalk Application"))
                                {
                                    Deploy-BTDFApplication @undeployParams
                                }
                            }
                            finally
                            {
                                $backRefs.Push($a)
                            }
                            Write-Verbose "Removed back reference: $($a.Name)"
                        }
                        else
                        {
                            Write-Warning "$($a.Name) already removed"
                        }
                    }
                    if (($backRefs.Count -gt 0) -and ($btsApps.Count -gt 0))
                    {
                        Write-Debug ($backRefs.GetEnumerator() | Out-String)
                    }
                }
                else
                {
                    Write-Verbose "No back references"
                }
                $backRefsRemoved = $true
            }
            catch
            {
                Write-Error -Message "Undeploying back references failed" -ErrorAction Continue
                Write-Error -Message "$_" -ErrorAction Continue
            }
            #endregion

            #region Calculate deployment variables
            #Calculate required properties
            $deployment = (Get-ChildItem -Path $pp -Filter *Deployment)[0]
            Write-Debug "Deployment = $($deployment.FullName)"
            $resultsPath = Join-Path -Path $pp -ChildPath "DeployResults\DeployResults.txt"
            if ($PSCmdlet.ShouldProcess($resultsPath, "Create empty MSBuild log file"))
            {
                New-Item -Path $resultsPath -ItemType File -Force | Out-Null
            }
            Write-Debug "Results = $resultsPath"

            #Get/Create project registry keys
            $manufacturerReg = if ($softwareReg32 | Join-Path -ChildPath $manufacturer | Test-Path)
            {
                $softwareReg32 | Join-Path -ChildPath $manufacturer | Get-Item
            }
            else
            {
                New-Item -Path $softwareReg32.PSPath -Name $manufacturer
                Write-Verbose "Created manufacturer key: $manufacturer"
            }

            $projectReg = if ($manufacturerReg | Join-Path -ChildPath $projectName | Test-Path)
            {
                $manufacturerReg | Join-Path -ChildPath $projectName | Get-Item
            }
            else
            {
                New-Item -Path $manufacturerReg.PSPath -Name $projectName
                Write-Verbose "Created project key: $projectName"
            }
        
            #Get properties from Application BTDF registry
            try
            {
                $version = $projectReg.GetValue("InstalledVersion")
                if (-not $version)
                {
                    throw
                }
                Write-Debug "Version = $version"
            }
            catch
            {
                Write-Warning "Unable to find version"
            }
            #endregion

            #region Run EnvironmentSettingsExporter
            if (($DeploymentType -eq "Deploy" -or $DeploymentType -eq "PreProcessBindings") -and ($Configuration -eq "Server"))
            {
                $envSettingsDir = $deployment | Join-Path -ChildPath "EnvironmentSettings" | Get-Item
                Write-Debug "Environment Settings Dir = $($envSettingsDir.FullName)"

                $settingsExporter = Join-Path -Path $deployment.FullName -ChildPath "Framework\DeployTools\EnvironmentSettingsExporter.exe"
                Write-Debug "Settings Exporter = $settingsExporter"
                if ($PSCmdlet.ShouldProcess($settingsExporter, "Exporting BTDF settings"))
                {
                    Invoke-Process -FilePath $settingsExporter `
                        -ArgumentList "`"$(Join-Path -Path $envSettingsDir.FullName -ChildPath \SettingsFileGenerator.xml)`"",
                    "`"$($envSettingsDir.FullName)`"" | Out-Null
                }
                $envSettings = Join-Path -Path $envSettingsDir -ChildPath "Exported_$Environment`Settings.xml" | Get-Item
                Write-Debug "Environment Settings = $($envSettings.FullName)"
            }
            #endregion

            #region Run MSBuild and deploy
            if ($backRefsRemoved)
            {
                $projectReg | New-ItemProperty -Name "Configuration" -Value $Configuration -Force | Out-Null
                $projectReg | New-ItemProperty -Name "LastDeploySettingsFilePath" -Value $envSettings.FullName -Force | Out-Null
                $projectReg | New-ItemProperty -Name "Version" -Value $version -Force | Out-Null
                Write-Verbose "$($btdfTargets[$DeploymentType]["Message"]): $projectName"
                $msbuildArgs = "/t:$($btdfTargets[$DeploymentType]["Target"])",
                $(if ($version)
                    {
                        "/p:ProductVersion=$version"
                    }),
                $(if (($DeploymentType -eq "Deploy") -and ($Configuration -eq "Server"))
                    {
                        "/p:ENV_SETTINGS=`"$($envSettings)`""
                    }),
                $(if ($PSBoundParameters.ContainsKey("TerminateInstances"))
                    {
                        "/p:AutoTerminateInstances=$TerminateInstances"
                    }),
                $(if ($Configuration)
                    {
                        "/p:Configuration=$Configuration"
                    }),
                $(if ($Configuration -eq "Server")
                    {
                        "/p:DeployBizTalkMgmtDB=$DeployBTMgmtDB"
                    }),
                $(if ($PSBoundParameters.ContainsKey("SkipBizTalkRestart"))
                    {
                        "/p:SkipHostInstancesRestart=$SkipBizTalkRestart"
                    }),
                $(if ($PSBoundParameters.ContainsKey("SkipIISRestart"))
                    {
                        "/p:SkipIISReset=$SkipIISRestart"
                    }),
                $(if ($PSBoundParameters.ContainsKey("SkipUnDeploy"))
                    {
                        "/p:SkipUndeploy=$SkipUnDeploy"
                    }),
                $(if ($PSBoundParameters.ContainsKey("SkipApplicationStart"))
                    {
                        "/p:StartApplicationOnDeploy=$(-not $SkipApplicationStart)"
                        "/p:StartReferencedApplicationsOnDeploy=$(-not $SkipApplicationStart)"
                    }),
                "/l:FileLogger,Microsoft.Build.Engine;logfile=`"$resultsPath`""
                if ($PSCmdlet.ShouldProcess($btdfProject, "Deploy BTDF packaged application"))
                {
                    Invoke-MSBuild -Project $btdfProject `
                        -ArgumentList $msbuildArgs `
                        -Version 4.0 `
                        -Run32Bit `
                        -ErrorAction Stop
                }
            }
            #endregion

            #region Restore back referenced applications in reverse
            if ($SkipRestore -and ($backRefs.Count -gt 0))
            {
                Write-Verbose "Skipping restore"
            }

            if (($backRefs.Count -gt 0) -and ($DeploymentType -eq "Deploy") -and (-not $SkipRestore))
            {
                Write-Debug "Back References Count = $($backRefs.Count)"
                while (($backRefs.Count -gt 0) -and ($DeploymentType -eq "Deploy"))
                {
                    $app = $backRefs.Pop()
                    Write-Verbose "Restoring: $($app.Name)"
                    $deployParams = $PSBoundParameters
                    $deployParams["ProjectPath"] = $app.ProjectPath
                    $deployParams["DeploymentType"] = $DeploymentType
                    $deployParams["Configuration"] = $Configuration
                    if ($PSCmdlet.ShouldProcess($app.Name, "Restoring BizTalk Application"))
                    {
                        Deploy-BTDFApplication @deployParams
                    }
                }
            }
            #endregion
        }
    }
}

<#
.SYNOPSIS
    Installs a BTDF packaged BizTalk application to the specified directory and deploys

.DESCRIPTION
    Requires Admin rights locally and for BizTalk. Locally installs a BTDF packaged BizTalk application to the specified directory and deploys. Deployment can be configured to support multi-server setups (install and gac assemblies on secondary nodes and register to BizTalk on primary node). This also takes into account applications which references an application to be upgraded and will strip and redeploy these. Supports configuration of multiple environments which are validated (cmdlet will need to be modified to support additional environments)

.PARAMETER MsiFile
    Path to the MsiFile

.PARAMETER TargetDir
    Path for the directory to install the application. The application will be installed WITHIN the specified folder rather than autocreating a folder

.PARAMETER DeploymentType
    Choose whether to DEPLOY and UNDEPLOY the BizTalk application (Default is DEPLOY)

.PARAMETER Environment
    Select the environment to deploy. Must match what is configured in BTDF environmentsettings spreadsheet(Defaults to Local)(Alter validated set if needed)

.PARAMETER DeployBTMgmtDB
    Registers application in BizTalk (Without this only the assemblies/components are GACed)

.PARAMETER SkipUnDeploy
    Skip undeploying application prior to deployment (deploy only instead of redeploy)

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
    Install application components/assemblies

    C:\PS> Install-BTDFApplication -MsiFile C:\Deployments\Scratchpad.msi -TargetDir "C:\Program Files (x86)\Scratchpad"

.EXAMPLE
    Install application and register in BizTalk

    C:\PS> Install-BTDFApplication -MsiFile C:\Deployments\Scratchpad.msi -TargetDir "C:\Program Files (x86)\Scratchpad" -DeployBTMgmtDB

.EXAMPLE
    Install application and register in BizTalk with live environment settings

    C:\PS> Install-BTDFApplication -MsiFile C:\Deployments\Scratchpad.msi -TargetDir "C:\Program Files (x86)\Scratchpad" -Environment Prod -DeployBTMgmtDB

.EXAMPLE
    Undeploys application and removes from BizTalk

    C:\PS> Install-BTDFApplication -MsiFile C:\Deployments\Scratchpad.msi -TargetDir "C:\Program Files (x86)\Scratchpad" -DeploymentType UnDeploy -DeployBTMgmtDB
#>
function Install-BTDFApplication
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param (
        [Parameter(Position = 0, Mandatory = $true, HelpMessage = "Path to existing BTDF MSI")]
        [ValidateScript( { Test-Path -Path $_.Fullname -PathType Leaf -Include *.msi })]
        [System.IO.FileInfo]$MsiFile,

        [Parameter(Position = 1, Mandatory = $true, HelpMessage = "Path wherein the resource files will be installed")]
        [System.IO.DirectoryInfo]$TargetDir,

        [Parameter(HelpMessage = "Valid parameters as Deploy, Undeploy, UpdateOrchestration. Defaults to Deploy")]
        [ValidateSet("Deploy", "UnDeploy", "UpdateOrchestration")]
        [string]$DeploymentType = "Deploy",

        [Parameter(HelpMessage = "Valid parameters are Local, Dev, Int, UAT, Train and Prod. Defaults to Local")]
        [ValidateSet("Local", "Dev", "Int", "UAT", "Train", "Prod")]
        [string]$Environment = "Local",

        [Parameter(HelpMessage = "Register artifacts in BizTalk DB")]
        [switch]$DeployBTMgmtDB,
  
        [Parameter(HelpMessage = "Only deploy instead of redeploy")]
        [switch]$SkipUnDeploy,

        [Parameter(HelpMessage = "Skip starting BizTalk hosts back up post deployment")]
        [switch]$SkipBizTalkRestart,

        [Parameter(HelpMessage = "Skip IISReset post deployment")]
        [switch]$SkipIISRestart,

        [Parameter(HelpMessage = "Skipping starting BizTalk app post deployment")]
        [switch]$SkipApplicationStart,

        [Parameter(HelpMessage = "Terminate instances related to deployed app")]
        [switch]$TerminateInstances,

        [Parameter(HelpMessage = "Skip restoring dependant applications")]
        [switch]$SkipRestore
    )
    Process
    {
        $TargetDir = Install-MsiFile -MsiFile $MsiFile -TargetDir $TargetDir

        #region Build splat params
        $splatParams = @{ }
        if ($PSBoundParameters.ContainsKey("DeployBTMgmtDB"))
        {
            $splatParams.Add("DeployBTMgmtDB", $DeployBTMgmtDB)
        }
        if ($PSBoundParameters.ContainsKey("SkipUndeploy"))
        {
            $splatParams.Add("SkipUndeploy", $SkipUndeploy)
        }
        if ($PSBoundParameters.ContainsKey("SkipBizTalkRestart"))
        {
            $splatParams.Add("SkipBizTalkRestart", $SkipBizTalkRestart)
        }
        if ($PSBoundParameters.ContainsKey("SkipIISRestart"))
        {
            $splatParams.Add("SkipIISRestart", $SkipIISRestart)
        }
        if ($PSBoundParameters.ContainsKey("SkipApplicationStart"))
        {
            $splatParams.Add("SkipApplicationStart", $SkipApplicationStart)
        }
        if ($PSBoundParameters.ContainsKey("TerminateInstances"))
        {
            $splatParams.Add("TerminateInstances", $TerminateInstances)
        }
        if ($PSBoundParameters.ContainsKey("SkipRestore"))
        {
            $splatParams.Add("SkipRestore", $SkipRestore)
        }
        #endregion
            
        Deploy-BTDFApplication -ProjectPath  $TargetDir `
            -Configuration "Server" `
            -DeploymentType $DeploymentType `
            -Environment $Environment `
            @splatParams
    }
}
#endregion

#region SSO

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
function Read-SSO
{
    [CmdletBinding()]
    [OutputType([hashtable])]
    Param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Application
    )
    Process
    {
        return [SSOSettingsFileReader]::Read($Application)
    }
}

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
function Read-SSOInt32
{
    [CmdletBinding()]
    [OutputType([int])]
    Param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string]$Application,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Value
    )
    Process
    {
        return [SSOSettingsFileReader]::ReadInt32($Application, $Value)
    }
}

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
    PS C:\> Read-SSO -Application Scratchpad -Value StringSetting
    Returns a string typed value from SSO for the Scatchpad appliction for the setting "StringSetting"

.OUTPUTS
    string
#>
function Read-SSOString
{
    [CmdletBinding()]
    [OutputType([string])]
    Param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string]$Application,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Value
    )
    Process
    {
        return [SSOSettingsFileReader]::ReadString($Application, $Value)
    }
}

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
function Write-SSOSetting
{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string]$Application,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Setting,
        [Parameter(Mandatory = $true, Position = 2)]
        [string]$Value
    )
    Process
    {
        [SSOSettingsFileManager.SSOSettingsManager]::WriteSetting($Application, $Setting, $Value)
    }
}
#endregion

#region Private
function Connect-BTSCatalog
{
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
    Process
    {        
        #Calculate BizTalk connection string
        $wmi = Get-WmiObject -Class MSBTS_GroupSetting -Namespace root\MicrosoftBizTalkServer -ComputerName $server -ErrorAction Stop
        if (-not $SQLInstance)
        {
            $SQLInstance = $wmi.MgmtDbServerName
        }
        if (-not $ManagementDB)
        {
            $ManagementDB = $wmi.MgmtDbName
        }

        $btsCatalog = [Microsoft.BizTalk.ExplorerOM.BtsCatalogExplorer]::new()
        $btsCatalog.ConnectionString = "SERVER=$SQLInstance;DATABASE=$ManagementDB;Integrated Security=SSPI"

        return $btsCatalog
    }
}

Function Install-MsiFile
{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [ValidateScript( { Test-Path -Path $_ -PathType Leaf -Include *.msi })]
        [string]$MsiFile,

        [Parameter()]
        [ValidateNotNullorEmpty()]
        [string]$TargetDir,

        [Parameter()]
        [ValidateNotNullorEmpty()]
        [System.Collections.Generic.List[string]]$ArgumentList
    )
    Process
    {
        $ArgumentList += "/i",
        "`"$msiFile`"",
        $(if ($targetDir)
            {
                "INSTALLDIR=`"$targetDir`""
            }),
        "ADDLOCAL=ALL",
        "/qn",
        "/norestart"

        Write-Verbose "Installing MSI File..."
        $process = Invoke-Process -FilePath "$env:windir\System32\msiexec.exe" -ArgumentList $ArgumentList

        switch ($process.ExitCode)
        {
            0
            {
                Write-Verbose "MSI been successfully installed"
            }
            Default
            {
                Write-Error "Installing $MsiFile failed!, Exit Code: $($process.ExitCode)"
            }
        }
        return $TargetDir
    }
}

function Invoke-MSBuild
{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [ValidateScript( { Test-Path -Path $_ -PathType Leaf -Include *.*proj })]
        [string]$Project,
        
        [Parameter(Position = 1)]
        [System.Collections.Generic.List[string]]$ArgumentList,

        [Parameter()]
        [switch]$Run32Bit

        # [Parameter()]
        # [ValidateNotNullOrEmpty()]
        # [ValidateScript({[version]::Parse($_)})]
        # [string]$Version
    )
    DynamicParam
    {
        $msbuildReg = if ($Run32Bit -and ($env:PROCESSOR_ARCHITECTURE -eq "AMD64"))
        {
            Get-Item -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\MSBuild\ToolsVersions"
        }
        else
        {
            Get-Item -Path "HKLM:\SOFTWARE\Microsoft\MSBuild\ToolsVersions"
        }

        $versions = $msbuildReg | Get-ChildItem | Get-ItemProperty | Sort-Object -Property @{Expression = { [version]::Parse($_.PSChildName) } } -Descending

        $paramDict = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        #region Version
        $attributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $parameter = New-Object System.Management.Automation.ParameterAttribute
        $attributeCollection.Add($parameter)
        $validateSet = New-Object System.Management.Automation.ValidateSetAttribute($versions | Select-Object -ExpandProperty PSChildName)
        $attributeCollection.Add($validateSet)
        $versionParameter = New-Object System.Management.Automation.RuntimeDefinedParameter("Version", [string], $attributeCollection)
        $paramDict.Add("Version", $versionParameter)
        #endregion

        return $paramDict
    }
    Process
    {
        $versionsHash = @{ }
        $versions | ForEach-Object {
            $versionsHash[$($_.PSChildName)] = $_.MSBuildToolsPath
        }

        $version = if (-not $PSBoundParameters.ContainsKey("Version"))
        {
            $versions[0].PSChildName
        }
        else
        {
            $PSBoundParameters.Version
        }
        Write-Debug "Version = $version"

        $msbuildFolder = $versionsHash[$version]
        Write-Debug "MSBuildFolder = $msbuildFolder"
        $msbuild = Join-Path -Path $msbuildFolder -ChildPath "msbuild.exe"
        $ArgumentList = "`"$Project`"",
        $ArgumentList,
        "/p:UseSharedCompilation=false",
        "/noLogo",
        "/maxcpucount:1",
        "/nodeReuse:false"
        Invoke-Process -FilePath $msbuild -ArgumentList $ArgumentList | Out-Null
    }
} 

function Invoke-Process
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( { Test-Path -Path $_ -PathType Leaf -Include *.* })]
        [System.IO.FileInfo]$FilePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]$ArgumentList
    )
    Process
    {
        $stdOutTempFile = "$env:TEMP\$((New-Guid).Guid)"
        $stdErrTempFile = "$env:TEMP\$((New-Guid).Guid)"

        Write-Verbose "Invoking $($FilePath.Name)"
        $processParams = @{
            "FilePath"    = $FilePath.FullName
            "Wait"        = $true
            "PassThru"    = $true
            "NoNewWindow" = $true
        }
        Write-Debug "FilePath = $($FilePath.FullName)"
        if ($ArgumentList)
        {
            $processParams.Add("ArgumentList", $ArgumentList)
            Write-Debug "ArgumentList = $ArgumentList"
        }

        #Redirect output if executed remotely
        if ((Get-Host).Name -eq "ServerRemoteHost")
        {
            $processParams["RedirectStandardOutput"] = $stdOutTempFile
            $processParams["RedirectStandardError"] = $stdErrTempFile
            Write-Debug "TempStdOutput = $stdOutTempFile"
            Write-Debug "TempStdError = $stdErrTempFile"
        }

        try
        {
            $process = Start-Process @processParams

            switch ($process.ExitCode)
            {
                0
                {
                    Write-Verbose "Process has been successfully run"
                    return $process
                }
                Default
                {
                    throw "Process failed!, Exit Code: $($process.ExitCode)"
                }
            }
        }
        catch
        {
            throw $_
        }
        finally
        {
            if ((Get-Host).Name -eq "ServerRemoteHost")
            {
                $processOutput = (Get-Content -Path $stdOutTempFile -Raw)
                $processError = Get-Content -Path $stdErrTempFile -Raw
                if ($processOutput)
                {
                    Write-Information $processOutput
                }
                if ($processError)
                {
                    Write-Error $processError
                }
            }

            Remove-Item -Path $stdOutTempFile, $stdErrTempFile `
                -Force `
                -Verbose:$false `
                -ErrorAction Ignore `
        
        }
    }
}
#endregion

#region Variables
$btsCatalog = Connect-BTSCatalog

$projectPathColumn = @{Name = "ProjectPath"; Expression = { Read-SSOString -Application $_.Name -Value "ProjectPath" } }

$softwareReg32 = if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64")
{
    Get-Item -Path HKLM:\SOFTWARE\Wow6432Node
}
else
{
    Get-Item -Path HKLM:\SOFTWARE
}

$btdfTargets = @{
    "BounceBizTalk"      = @{
        "Message" = "Boucing BizTalk"
        "Target"  = "BounceBizTalk"
    }
    "Deploy"             = @{
        "Message" = "Deploying application"
        "Target"  = "Deploy"
    }
    "DeployBAM"          = @{
        "Message" = "Deploying BAM"
        "Target"  = "GetSoftwarePaths;InitializeAppName;DeployBAM"
    }
    "DeployBRE"          = @{
        "Message" = "Deploying BRE" 
        "Target"  = "DeployVocabAndRules"
    }
    "DeploySSO"          = @{
        "Message" = "Deploying SSO"
        "Target"  = "DeploySSO"
    }
    "Installer"          = @{
        "Message" = "Packaging"
        "Target"  = "Installer"
    }
    "PreProcessBindings" = @{
        "Message" = "Pre-Processing bindings"
        "Target"  = "PreprocessBindings"
    }
    "QuickDeploy"        = @{
        "Message" = "Quick deploying application"
        "Target"  = "UpdateOrchestration"
    }
    "Undeploy"           = @{
        "Message" = "Undeploying application"
        "Target"  = "Undeploy"
    }
    "UndeployBAM"        = @{
        "Message" = "Undeploying BAM"
        "Target"  = "GetSoftwarePaths;InitializeAppName;UndeployBAM"
    }
    "UndeployBRE"        = @{
        "Message" = "Undeploying BRE"
        "Target"  = "UndeployVocabAndRules"
    }
}
#endregion