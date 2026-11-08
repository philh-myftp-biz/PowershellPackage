
$ModuleRoot = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

Get-ChildItem `
    -Path "$ModuleRoot\src" `
    -Filter *.psm1 `
    -Recurse `
    | ForEach-Object {
        Import-Module $_.FullName -Force
    }

