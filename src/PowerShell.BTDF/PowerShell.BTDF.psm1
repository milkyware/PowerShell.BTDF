Param (
)
Process {
    #region Execute module scripts
    Get-ChildItem -Path $PSScriptRoot -Include *.ps1 -Recurse | ForEach-Object {
        . $_.FullName
    }
    #endregion

    #region Variables
    $btsCatalog = Connect-BTSCatalog

    $projectPathColumn = @{Name="ProjectPath";Expression={Read-SSOString -Application $_.Name -Value "ProjectPath"}}

    $softwareReg32 = if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64") {
        Get-Item -Path HKLM:\SOFTWARE\Wow6432Node
    } else {
        Get-Item -Path HKLM:\SOFTWARE
    }

    $btdfTargets = @{
        "Deploy" = @{
            "Message" = "Deploying application"
            "Target" = "Deploy"
        }
        "DeployBAM" = @{
            "Message" = "Deploying BAM"
            "Target" = "GetSoftwarePaths;InitializeAppName;DeployBAM"
        }
        "DeployBRE" = @{
            "Message" = "Deploying BRE" 
            "Target" = "DeployVocabAndRules"
        }
        "DeploySSO" = @{
            "Message" = "Deploying SSO"
            "Target" = "DeploySSO"
        }
        "Installer" = @{
            "Message" = "Packaging"
            "Target" = "Installer"
        }
        "PreProcessBindings" = @{
            "Message" = "Pre-Processing bindings"
            "Target" = "PreprocessBindings"
        }
        "QuickDeploy" = @{
            "Message" = "Quick deploying application"
            "Target" = "UpdateOrchestration"
        }
        "Undeploy" = @{
            "Message" = "Undeploying application"
            "Target" = "Undeploy"
        }
        "UndeployBAM" = @{
            "Message" = "Undeploying BAM"
            "Target" = "GetSoftwarePaths;InitializeAppName;UndeployBAM"
        }
        "UndeployBRE" = @{
            "Message" = "Undeploying BRE"
            "Target" = "UndeployVocabAndRules"
        }
    }
    #endregion
}