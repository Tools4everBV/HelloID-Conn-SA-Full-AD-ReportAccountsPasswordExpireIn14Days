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
$searchOUs = $AdReportSearchOu

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

    $resultCount = 0
    foreach($adUser in $adUsers){
        if($null -ne $adUser.ExpiryDate){
            $expiryDate = $adUser.ExpiryDate
        
            If ($expiryDate.Year -ne 1600 -and $expiryDate -lt $dateBeforeExpire) {
                $formattedDate = $expiryDate.ToString("dd-MM-yyyy")
                
                Write-Output ([Ordered]@{
                    DisplayName=$adUser.displayName;
                    Name=$adUser.Name;
                    SamAccountName=$adUser.SamAccountName;
                    UserPrincipalName=$adUser.UserPrincipalName;
                    Mail=$adUser.mail;
                    Description=$adUser.Description;
                    ExpiryDate=$formattedDate;
                })
                $resultCount++
                
                if($debugLogging -eq $true){ Write-Verbose -Verbose "User $($adUser.Name)'s password will expire in $daysBeforeExpire days on: $formattedDate" }
            }
        }else{
            if($debugLogging -eq $true){ Write-Verbose -Verbose "User $($adUser.Name) has no ExpiryDate" }
        }
    }

    Write-Information "Result count: $resultCount"
}catch{
    $ex = $PSItem
    Write-Warning "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    Write-Error "Error $($actionMessage). Error: $($ex.Exception.Message)"
    # exit # use when using multiple try/catch and the script must stop
}
#endregion lookup
