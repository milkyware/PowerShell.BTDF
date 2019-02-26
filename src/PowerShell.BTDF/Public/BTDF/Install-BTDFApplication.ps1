#Requires -RunAsAdministrator

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

function Install-BTDFApplication {
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param (
        [Parameter(Position = 0, Mandatory = $true, HelpMessage = "Path to existing BTDF MSI")]
        [ValidateScript( {Test-Path -Path $_.Fullname -PathType Leaf -Include *.msi})]
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
    Process {
        $TargetDir = Install-MsiFile -MsiFile $MsiFile -TargetDir $TargetDir

        #region Build splat params
        $splatParams = @{}
        if ($PSBoundParameters.ContainsKey("DeployBTMgmtDB")) {
            $splatParams.Add("DeployBTMgmtDB", $DeployBTMgmtDB)
        }
        if ($PSBoundParameters.ContainsKey("SkipUndeploy")) {
            $splatParams.Add("SkipUndeploy", $SkipUndeploy)
        }
        if ($PSBoundParameters.ContainsKey("SkipBizTalkRestart")) {
            $splatParams.Add("SkipBizTalkRestart", $SkipBizTalkRestart)
        }
        if ($PSBoundParameters.ContainsKey("SkipIISRestart")) {
            $splatParams.Add("SkipIISRestart", $SkipIISRestart)
        }
        if ($PSBoundParameters.ContainsKey("SkipApplicationStart")) {
            $splatParams.Add("SkipApplicationStart", $SkipApplicationStart)
        }
        if ($PSBoundParameters.ContainsKey("TerminateInstances")) {
            $splatParams.Add("TerminateInstances", $TerminateInstances)
        }
        if ($PSBoundParameters.ContainsKey("SkipRestore")) {
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