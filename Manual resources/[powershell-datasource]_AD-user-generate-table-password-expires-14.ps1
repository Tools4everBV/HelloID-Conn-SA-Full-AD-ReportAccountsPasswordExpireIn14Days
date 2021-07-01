$debugLogging = $false
$daysBeforeExpire = 14

try{
    $dateBeforeExpire = (Get-Date).addDays($daysBeforeExpire).ToShortDateString()

    $adUsers = Get-ADUser -filter {Enabled -eq $True -and PasswordNeverExpires -eq $False} -Properties "SamAccountName","userPrincipalName", "displayName", "Name", "mail", "Description", "msDS-UserPasswordExpiryTimeComputed" |
        Select-Object "SamAccountName","userPrincipalName", "displayName","Name", "mail", "Description", @{Name="ExpiryDate";Expression={[datetime]::FromFileTime($_."msDS-UserPasswordExpiryTimeComputed").ToShortDateString() }}

    [System.Collections.ArrayList]$adUsersWithPasswordAboutToExpire =  @()
    foreach($adUser in $adUsers){
        if(![String]::IsNullOrEmpty($adUser.ExpiryDate)){
            [datetime]$ConvertDate = $adUser.ExpiryDate
            $ExpireDate = $ConvertDate.ToShortDateString()
        
            If ($ExpireDate -eq $dateBeforeExpire) {
                $null = $adUsersWithPasswordAboutToExpire.Add($adUser)
                if($debugLogging -eq $true){ Write-Verbose -Verbose "User $($adUser.Name)'s password will expire in $daysBeforeExpire days on: $($adUser.ExpiryDate)" }
            }
        }else{
            if($debugLogging -eq $true){ Write-Verbose -Verbose "User $($adUser.Name) has no ExpiryDate" }
        }
    }

    $resultCount = @($adUsersWithPasswordAboutToExpire).Count
    Write-Information "Result count: $resultCount"
        
    if($resultCount -gt 0){
        foreach($user in $adUsersWithPasswordAboutToExpire){
            $returnObject = [Ordered]@{
                DisplayName=$user.displayName;
                Name=$user.Name;
                SamAccountName=$user.SamAccountName;
                UserPrincipalName=$user.UserPrincipalName;
                Mail=$user.mail;
                Description=$user.Description;
                ExpiryDate=$user.ExpiryDate
            }
            Write-Output $returnObject
        }
    }
}catch{
    throw "Could not gather users with passwords about to expire in $daysBeforeExpire days. Error: $_"
}
