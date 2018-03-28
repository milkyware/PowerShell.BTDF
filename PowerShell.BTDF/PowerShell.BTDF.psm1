Param (
)
Process {
    #Execute module scripts
    Get-ChildItem -Path $PSScriptRoot -Include *.ps1 -Recurse | ForEach-Object {
        . $_.FullName
    }
}