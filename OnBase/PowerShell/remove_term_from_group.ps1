 <#
.SYNOPSIS
    Removes terminated employees listed in a text file from the specified Active Directory group.
.DESCRIPTION
    Runs by default in DRY RUN mode for safety.
    To execute real removals, run with:
        .\ScriptName.ps1 -Mode live
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('dry', 'live')]
    [string]$Mode = 'dry'
)

Import-Module ActiveDirectory

# --- CONFIGURATION ---
$InputFilePath = "G:\Shared drives\OnBase Administration\Reports\Access Group Audits\AD Groups\term_users.txt"
$NameStem      = "ua_onbase."
$GroupName     = "user.prod"

# Derive execution flag from parameter
$ExecuteRemovals = ($Mode -eq 'live')

# --- Get the group name from the command line
$in = Read-Host -Prompt "Which OnBase group (def: user.prod)? [ua_onbase.]" 
if ($in -ne "") {
    $GroupName = $in.ToLower().Trim()
}
$TargetGroupName = $NameStem + $GroupName

# --- EXECUTION ---

if (-not (Test-Path -Path $InputFilePath)) {
    Write-Error "The specified file was not found: $InputFilePath"
    # Keep window open on error if right-clicked
    Read-Host -Prompt "`nPress Enter to exit"
    exit
}

# Read usernames
$TerminatedUsers = Get-Content -Path $InputFilePath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() }
Write-Host "Found $($TerminatedUsers.Count) usernames in the input file." -ForegroundColor Cyan

# Display current Mode Banner
if ($ExecuteRemovals) {
    Write-Host "`n***************************************************" -ForegroundColor Red
    Write-Host " RUNNING IN LIVE REMOVAL MODE - CHANGES WILL BE MADE" -ForegroundColor Red
    Write-Host "***************************************************`n" -ForegroundColor Red
} else {
    Write-Host "`n--- DRY RUN MODE (No changes will be made) ---" -ForegroundColor Yellow
    Write-Host "To execute real removals, run script with: -Mode live`n" -ForegroundColor Yellow
}

# 1. Verify group exists
try {
    $Group = Get-ADGroup -Identity $TargetGroupName -ErrorAction Stop
} catch {
    Write-Error "Could not find the target group '$TargetGroupName' in Active Directory."
    Read-Host -Prompt "`nPress Enter to exit"
    exit
}

# --- 1.5 CONFIRMATION SAFETY CHECK ---
$confirmation = Read-Host -Prompt "I am going to update group $TargetGroupName in [$($Mode.ToUpper())] mode. Are you sure? [y/N]"
if ($confirmation.ToLower().Trim() -notmatch '^(y|yes)$') {
    Write-Host "`nOperation canceled by user. Exiting script." -ForegroundColor Yellow
    Read-Host -Prompt "`nPress Enter to exit"
    exit
}
Write-Host "Confirmed. Proceeding with group check...`n" -ForegroundColor Green

# 2. FAST LOOKUP: Fetch group members ONCE into a hashtable/set for instant checking
Write-Host "Fetching current group membership for '$TargetGroupName'..." -ForegroundColor Cyan
$CurrentMembers = Get-ADUser -Filter "memberOf -eq '$($Group.DistinguishedName)'" | Select-Object -ExpandProperty SamAccountName

# Convert to a HashSet for fast in-memory checking
$MemberSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$CurrentMembers | ForEach-Object { [void]$MemberSet.Add($_) }

Write-Host "Group currently has $($MemberSet.Count) members. Processing term list...`n" -ForegroundColor Cyan

# 3. Process each user using local memory matching
foreach ($Username in $TerminatedUsers) {
    
    if ($MemberSet.Contains($Username)) {
        
        if ($ExecuteRemovals) {
            try {
                Remove-ADGroupMember -Identity $Group -Members $Username -Confirm:$false -ErrorAction Stop
                Write-Host "[REMOVED] $Username was removed from $TargetGroupName" -ForegroundColor Green
            } catch {
                Write-Host "[ERROR] Failed removing '$Username': $_" -ForegroundColor Red
            }
        } else {
            Write-Host "[WOULD REMOVE] $Username is currently in the group and would be removed." -ForegroundColor Yellow
        }
        
    } else {
        Write-Host "[SKIP] $Username is not a member of $TargetGroupName" -ForegroundColor DarkGray
    }
}

Write-Host "`nProcessing complete." -ForegroundColor Cyan

# --- PREVENT WINDOW FROM CLOSING ON RIGHT-CLICK RUN ---
Write-Host ""
Read-Host -Prompt "Press Enter to exit" 
