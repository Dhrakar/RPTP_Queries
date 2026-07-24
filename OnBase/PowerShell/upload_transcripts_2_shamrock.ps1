# set the globals
# Note the log appends for the month and then starts over the next month
$LogPath     = "C:\BatchFiles\logs\ShamrockExport_$(Get-Date -Format 'yyyyMM').log"
$exportPath  = "C:\EXPORT\Shamrock\"
$archivePath = "C:\EXPORT\Shamrock\Uploaded\"
$targetPath  = "/upload"

# Start the transcript logging
Start-Transcript -Path $LogPath -Append

Write-Output "Initial setup and import of Posh-SSH ..."
# 0. Ensure that we have the Posh-SSH module for the extended SFTP actions
Import-Module Posh-SSH -ErrorAction Stop

# 1. Setup credentials safely in-memory
$SecurePassword = ConvertTo-SecureString "8Tza23R7ju4FHSOCXwB5ckQJ" -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ("UAF_user_1", $SecurePassword)

Write-Output "Creating SFTP Session ..."
# 2. Create a new SFTP Connection to the server
$Session = New-SFTPSession -ComputerName "s-f0ae1c2e8f6448c49.server.transfer.us-east-2.amazonaws.com" -Credential $Credential -Force

# 3. Get a listing of the current files in Shamrock
Write-Output "Fetching directory listing for $targetPath ..."

Get-SFTPChildItem -SFTPSession $Session -Path $targetPath | 
    Select-Object Name, Length, LastWriteTime | 
    Format-Table -AutoSize

# 4. Upload any transcripts in the Export directory

# Get all transcript files waiting in your local export folder
$LocalFiles = Get-ChildItem -Path $exportPath -File

# iterate through the found files
foreach ($File in $LocalFiles) {
    Write-Output "Uploading $($File.Name) to Shamrock SFTP..."
    
    # Push the file straight into the permitted /upload path
    Set-SFTPItem -SFTPSession $Session -Path $File.FullName -Destination $targetPath
    
    # Optional: Archive or delete the local file after a successful upload
    Move-Item -Path $File.FullName -Destination $archivePath
}

# 4. Safely close the test session
Remove-SFTPSession $Session

# End logging
Stop-Transcript