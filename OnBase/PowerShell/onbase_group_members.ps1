 <#
.SYNOPSIS
    Fast, timeout-resistant script to export members of large AD groups.
#>

Import-Module ActiveDirectory

$NameStem  = "ua_onbase."
$GroupName = "user.prod"
$ts = (Get-Date).toString("yyyyMMdd")

# --- Get the group name from the command line
$in = Read-Host -Prompt "Which OnBase group (def: user.prod)? [ua_onbase.]" 
if ($in -ne "") {
    $GroupName = $in.ToLower().Trim()
}

# Fixed variable name: $NameStem instead of $GroupNameStem
$TargetGroupName = $NameStem + $GroupName
$ExportFileName = $ts + " AD Group " + $GroupName + ".csv"
$ExportCsvPath   = "G:\Shared drives\OnBase Administration\Reports\Access Group Audits\AD Groups\" + $ExportFileName

# --- EXECUTION ---

Write-Host "Fetching members from '$TargetGroupName' (Optimized for large groups)..." -ForegroundColor Cyan

try {
    # 1. Fetch the Group DistinguishedName
    $Group = Get-ADGroup -Identity $TargetGroupName -ErrorAction Stop

    # 2. Query Get-ADUser directly using the LDAP MemberOf filter
    $Members = Get-ADUser -Filter "memberOf -eq '$($Group.DistinguishedName)'" -Properties DisplayName, Mail, Enabled, GivenName, Surname

    # Check if the group actually has members
    if ($Members.Count -eq 0) {
        Write-Host "Group '$TargetGroupName' exists, but has no members." -ForegroundColor Yellow
        return
    }

    Write-Host "Found $($Members.Count) members. Formatting output..." -ForegroundColor Yellow

    # 3. Process properties
    $Report = foreach ($User in $Members) {
        [PSCustomObject]@{
            Username      = $User.SamAccountName
            DisplayName   = $User.DisplayName
            AccountActive = $User.Enabled
        }
    }

    # 4. Export to CSV
    $Report | Export-Csv -Path $ExportCsvPath -NoTypeInformation -Encoding UTF8

    Write-Host "Success! Exported $($Report.Count) users to: $ExportCsvPath" -ForegroundColor Green

} 
# --- SPECIFIC ERROR CATCHING ---
catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    # This specifically catches invalid/missing AD group names!
    Write-Host "`n[WARNING] Could not find the AD group '$TargetGroupName'." -ForegroundColor Red
    Write-Host "Please check the group spelling and try again.`n" -ForegroundColor Yellow
}
catch {
    # Generic catch-all for any unexpected errors (permissions, file locks, etc.)
    Write-Host "`n[ERROR] An unexpected error occurred: $_" -ForegroundColor Red
} 
