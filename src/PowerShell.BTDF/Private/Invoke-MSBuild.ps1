function Invoke-MSBuild {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
        [ValidateScript({Test-Path -Path $_ -PathType Leaf -Include *.*proj})]
        [string]$Project,
        
        [Parameter(Position=1)]
        [System.Collections.Generic.List[string]]$ArgumentList,

        [Parameter()]
        [switch]$Run32Bit

        # [Parameter()]
        # [ValidateNotNullOrEmpty()]
        # [ValidateScript({[version]::Parse($_)})]
        # [string]$Version
    )
    DynamicParam {
        $msbuildReg = if ($Run32Bit -and ($env:PROCESSOR_ARCHITECTURE -eq "AMD64")) {
            Get-Item -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\MSBuild\ToolsVersions"
        } else {
            Get-Item -Path "HKLM:\SOFTWARE\Microsoft\MSBuild\ToolsVersions"
        }

        $versions = $msbuildReg | Get-ChildItem | Get-ItemProperty | Sort-Object -Property @{Expression={[version]::Parse($_.PSChildName)}} -Descending

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
    Process {
        $versionsHash = @{}
        $versions| ForEach-Object {
            $versionsHash[$($_.PSChildName)] = $_.MSBuildToolsPath
        }

        $version = if (-not $PSBoundParameters.ContainsKey("Version")) {
            $versions[0].PSChildName
        } else {
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