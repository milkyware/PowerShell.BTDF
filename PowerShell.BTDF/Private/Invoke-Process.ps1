function Invoke-Process {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( {Test-Path -Path $_ -PathType Leaf -Include *.*})]
        [System.IO.FileInfo]$FilePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]$ArgumentList
    )
    Process {
        $stdOutTempFile = "$env:TEMP\$((New-Guid).Guid)"
        $stdErrTempFile = "$env:TEMP\$((New-Guid).Guid)"

        Write-Verbose "Invoking $($FilePath.Name)..."
        $processParams = @{
            "FilePath" = $FilePath.FullName
            "Wait" = $true
            "PassThru" = $true
            "NoNewWindow" = $true
        }
        Write-Debug "FilePath = $($FilePath.FullName)"
        if ($ArgumentList) {
            $processParams.Add("ArgumentList", $ArgumentList)
            Write-Debug "ArgumentList = $ArgumentList"
        }

        #Redirect output if executed remotely
        if ((Get-Host).Name -eq "ServerRemoteHost") {
            $processParams["RedirectStandardOutput"] = $stdOutTempFile
            $processParams["RedirectStandardError"] = $stdErrTempFile
            Write-Debug "TempStdOutput = $stdOutTempFile"
            Write-Debug "TempStdError = $stdErrTempFile"
        }

        try {
            $process = Start-Process @processParams

            switch ($process.ExitCode) {
                0 {
                    Write-Verbose "Process has been successfully run"
                    return $process
                }
                Default {
                    throw "Process failed!, Exit Code: $($process.ExitCode)"
                }
            }
        }
        catch {
            throw $_
        }
        finally {
            if ((Get-Host).Name -eq "ServerRemoteHost") {
                $processOutput = (Get-Content -Path $stdOutTempFile -Raw)
                $processError = Get-Content -Path $stdErrTempFile -Raw
                if ($processOutput) {
                    Write-Information $processOutput
                }
                if ($processError) {
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