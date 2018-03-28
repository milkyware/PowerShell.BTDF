Function Install-MsiFile {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelinebyPropertyName=$true)]
        [ValidateScript({Test-Path -Path $_ -PathType Leaf -Include *.msi})]
        [string]$MsiFile,

        [Parameter()]
        [ValidateNotNullorEmpty()]
        [string]$TargetDir,

        [Parameter()]
        [ValidateNotNullorEmpty()]
        [System.Collections.Generic.List[string]]$ArgumentList
    )
    Process {
        $ArgumentList += "/i",
            "`"$msiFile`"",
            $(if ($targetDir){
                "INSTALLDIR=`"$targetDir`""
            }),
            "ADDLOCAL=ALL",
            "/qn",
            "/norestart"

        Write-Verbose "Installing MSI File..."
        $process = Invoke-Process -FilePath "$env:windir\System32\msiexec.exe" -ArgumentList $ArgumentList

        switch ($process.ExitCode) {
            0 {
                Write-Verbose "MSI been successfully installed"
            }
            Default {
                Write-Error "Installing $MsiFile failed!, Exit Code: $($process.ExitCode)"
            }
        }
        return $TargetDir
    }
}