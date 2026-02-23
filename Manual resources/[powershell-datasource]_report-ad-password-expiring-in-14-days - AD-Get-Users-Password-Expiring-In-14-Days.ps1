#######################################################################
# Template: HelloID SA Powershell data source
# Name: report-ad-password-expiring-in-14-days | AD-Get-Users-Password-Expiring-In-14-Days
# Date: 23-02-2026
#######################################################################

# For basic information about powershell data sources see:
# https://docs.helloid.com/en/service-automation/dynamic-forms/data-sources/powershell-data-sources.html

# Service automation variables:
# https://docs.helloid.com/en/service-automation/service-automation-variables.html

#region init

$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

$debugLogging = $false
$daysBeforeExpire = 14

# global variables (Automation --> Variable library):
$searchOUs = $AdUsersReportOu

# variables configured in form:
# $formValue1 = $datasource.<formElementKey>.<value>
# $formValue2 = $datasource.<formElementKey>

#endregion init

#region functions

#endregion functions

#region lookup
try{
    $actionMessage = "querying AD for users with passwords expiring in $daysBeforeExpire days"
    $filter = {Enabled -eq $True -and PasswordNeverExpires -eq $False}
    $properties = "SamAccountName","userPrincipalName", "displayName", "Name", "mail", "Description", "msDS-UserPasswordExpiryTimeComputed"
    $dateBeforeExpire = (Get-Date).addDays($daysBeforeExpire)

    $ous = $searchOUs -split ';'
    $adUsers = foreach($item in $ous) {
        Get-ADUser -filter $filter -SearchBase $item -Properties $properties | Select-Object "SamAccountName","userPrincipalName", "displayName","Name", "mail", "Description", @{Name="ExpiryDate";Expression={[datetime]::FromFileTime($_."msDS-UserPasswordExpiryTimeComputed") }}
    }

    [System.Collections.ArrayList]$adUsersWithPasswordAboutToExpire =  @()
    foreach($adUser in $adUsers){
        if($null -ne $adUser.ExpiryDate){
            $expiryDate = $adUser.ExpiryDate
        
            If ($expiryDate.Year -ne 1600 -and $expiryDate -lt $dateBeforeExpire) {
                $formattedDate = $expiryDate.ToString("dd-MM-yyyy")
                $adUser | Add-Member -MemberType NoteProperty -Name FormattedDate -Value $formattedDate -Force

                $null = $adUsersWithPasswordAboutToExpire.Add($adUser)
                if($debugLogging -eq $true){ Write-Verbose -Verbose "User $($adUser.Name)'s password will expire in $daysBeforeExpire days on: $formattedDate" }
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
                ExpiryDate=$user.FormattedDate;
            }
            Write-Output $returnObject
        }
    } else {
        return
    }
}catch{
    $ex = $PSItem
    Write-Warning "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    Write-Error "Error $($actionMessage). Error: $($ex.Exception.Message)"
    # exit # use when using multiple try/catch and the script must stop
}
#endregion lookup
