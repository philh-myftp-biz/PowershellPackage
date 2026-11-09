
function Invoke-AtPath(

    [Parameter(Mandatory=$true, Position=0)]
    [string] $Path = '.',

    [Parameter(Mandatory=$true, Position=1)]
    [scriptblock] $Process

) {
    
    New-Item `
        -Path $Path `
        -ItemType Directory `
        -ErrorAction SilentlyContinue `
        | Out-Null
    
    Push-Location $Path
    try {
        & $Process
    } finally {
        Pop-Location
    }

}

