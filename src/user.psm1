
class User {
    [string] $FirstName
    [string] $LastName
    [string] $UserName
}

function Get-User (
    [String] $Name = $null,
    [String] $Domain = "philh.local"
) {

    $DcComponents = $Domain.Split('.') | ForEach-Object { "DC=$_" }
    $SearchBase = "CN=Users, $($DcComponents -join ',')"

    Get-ADUser -Filter * -SearchBase $SearchBase | ForEach-Object -Process {

        $user = [User]::new()
        $user.FirstName = $_.GivenName
        $user.LastName = $_.Surname
        $user.Username = $_.SamAccountName.ToLower()

        if (($user.Username -notin @('krbtgt', 'guest')) -and 
            (($null -eq $Name) -or ($Name.ToLower() -eq $user.UserName))
        ) {
            $user;
        }

    }

}

