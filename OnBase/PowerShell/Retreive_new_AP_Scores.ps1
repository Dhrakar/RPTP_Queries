# ==============================================================================
# College Board AP Scores Automation Script
# For Windows Task Scheduler / OnBase DIP-COLD Automation
# ==============================================================================

# Configuration
$DownloadLocation = "C:\COLD\AP Scores" # Translates from $HOME/Downloads
$Username         = "uaf-querymgr@alaska.edu"   # UAF Automation account
$Password         = "<see Keeper>"                          
$DiCode           = "4866"                       # Your DI code
$Format           = "TXT"                        # File format (TXT, CSV)
$DownloadType     = "new"                       # Download type (e.g., full, new)
# Note the log appends for the month and then starts over the next month
$LogPath          = "C:\BatchFiles\logs\CollegeBoard-API_$(Get-Date -Format 'yyyyMM').log"

# API Endpoints
$BaseUrl            = "https://aposrd-api-gw.collegeboard.org"
$AuthPath           = "/aposrd-api-prod/webServiceAuth"
$FilePath           = "/aposrd-api-prod/fileGeneration"
$RecordDownloadPath = "/aposrd-api-prod/webServiceDownloaded"

# Setup Base64 Encoding for Password (replaces echo -n | base64)
$Bytes          = [System.Text.Encoding]::UTF8.GetBytes($Password)
$Base64Password = [Convert]::ToBase64String($Bytes)

# Start the transcript logging
Start-Transcript -Path $LogPath -Append

# ------------------------------------------------------------------------------
# Step 1: Authenticate
# ------------------------------------------------------------------------------
Write-Host "Step 1/4: Authenticating..." -ForegroundColor Cyan

$AuthHeaders = @{
    "Content-Type"                        = "application/json"
    "Accept"                              = "application/json"
    "X-CB-Catapult-Authorization-Token"   = "CBLogin"
    "X-CB-Catapult-Authentication-Token"  = "CBLogin Web Service"
}

$AuthBody = @{
    u = $Username
    p = $Base64Password
} | ConvertTo-Json

# Invoke-RestMethod automatically parses the JSON response into a PowerShell object
$AuthResponse = Invoke-RestMethod -Uri "$BaseUrl$AuthPath" -Method Post -Headers $AuthHeaders -Body $AuthBody

if ($AuthResponse.success -ne $true) {
    Write-Error "Authentication failed: $($AuthResponse.message)"
    exit 1
}

$AuthToken = $AuthResponse.authToken
Write-Host "Authentication successful." -ForegroundColor Green

# ------------------------------------------------------------------------------
# Step 2: Generate File
# ------------------------------------------------------------------------------
Write-Host "Step 2/4: Generating file..." -ForegroundColor Cyan

$AuthenticatedHeaders = @{
    "Content-Type"                        = "application/json"
    "Accept"                              = "application/json"
    "X-CB-Catapult-Authorization-Token"   = $AuthToken
    "X-CB-Catapult-Authentication-Token"  = "CBLogin Web Service"
}

$FileBody = @{
    diCode       = $DiCode
    format       = $Format
    downloadType = $DownloadType
} | ConvertTo-Json

$FileResponse = Invoke-RestMethod -Uri "$BaseUrl$FilePath" -Method Post -Headers $AuthenticatedHeaders -Body $FileBody

if ($FileResponse.success -ne $true) {
    if ($FileResponse.message -like "*There were no score orders found*") {
        Write-Host "No new AP Scores available ... Exiting" -ForegroundColor Yellow
        Stop-Transcript
        exit 0
    }
    else {
        Write-Error "File generation failed: $($FileResponse.message)"
        exit 1
    }
}

$FileUrl    = $FileResponse.url
$FileName   = $FileResponse.fileName
$DownloadId = $FileResponse.downloadId

Write-Host "File generation successful." -ForegroundColor Green

# ------------------------------------------------------------------------------
# Step 3: Download File
# ------------------------------------------------------------------------------
Write-Host "Step 3/4: Downloading file..." -ForegroundColor Cyan
$DestinationPath = Join-Path $DownloadLocation $FileName

try {
    # Using Invoke-WebRequest for downloading the actual file payload to disk
    Invoke-WebRequest -Uri $FileUrl -OutFile $DestinationPath -Headers $AuthenticatedHeaders
    Write-Host "File downloaded successfully to $DestinationPath." -ForegroundColor Green
}
catch {
    Write-Error "File download failed: $_"
    exit 1
}

# ------------------------------------------------------------------------------
# Step 4: Record Successful Download
# ------------------------------------------------------------------------------
Write-Host "Step 4/4: Recording successful download..." -ForegroundColor Cyan

$RecordBody = @{
    downloadId = $DownloadId
    format     = $Format
} | ConvertTo-Json

$RecordResponse = Invoke-RestMethod -Uri "$BaseUrl$RecordDownloadPath" -Method Post -Headers $AuthenticatedHeaders -Body $RecordBody

if ($RecordResponse.success -ne $true) {
    Write-Error "Failed to record download: $($RecordResponse.message)"
    exit 1
}

Write-Host "Download successfully recorded. Ready for COLD import!" -ForegroundColor Green

# End logging
Stop-Transcript