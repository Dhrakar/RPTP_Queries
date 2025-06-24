# --------------------------------------------
# CollegeBoard AP scores report pre-processor
#
# This script takes the text file from 
# CollegeBoard and inserts line breaks where
# needed so that the COLD import can handle
# all the scores as a MIKG. It also adds the
# '@' to each original line for a record break
# in COLD
# --------------------------------------------

# Define the paths
$PATH = "C:\COLD\AP Scores\"
$LOG  = "C:\BatchFiles\logs\"

# default filenames
$inputFile  = $PATH + "AP_IMPORT.txt"
$outputFile = $PATH + "AP_IMPORT_PROCESSED.txt"
$logFile    = $LOG + "process_ap_reports.log"

# regular Expression that matches the 'AP_HED_Scores_4866_mmddyyyy_hhmm.txt' filename
$regEx = "^AP_HED_Scores.*\.txt$" 

# Array of col breaks for putting all 30 scores at col 1 of each line.  Each set is 11 chars total.
$columns = @(538, 549, 560, 571, 582, 593, 604, 615, 626, 637, 
             648, 659, 670, 681, 692, 703, 714, 725, 736, 747,
             758, 769, 780, 791, 802, 813, 824, 835, 846, 857,
             868 # put the report dates on a separate line 
            )

# timestamp
$stamp = Get-Date

# ---- Functions
Function DoLog {
    Param ([string]$message)

    # Build status message line
    $ts = (Get-Date).toString("dd MMM yyyy @ HH:mm")
    $out = "[ $ts ] $message "

    # console message
    #Write-Host $out
    #add to log
    Add-content $logFile -value $out
}

# ---- Main

# Log the start
DoLog "Preprocessor begin: $start"

# test to see if the input file is there 
if ( -Not (Test-Path $inputFile) ) {
    DoLog " --> no AP_IMPORT.txt file found"
    # or see if there is a new AP_HED file
    $apInputFile = ( # gets the oldest file that matches the regex (if any)
        Get-ChildItem -Path $PATH -File | Sort-Object LastWriteTime | Where-Object { $_.Name -match $regEx } | Select-Object -First 1
    ).Name
    if( -not $apInputFile) {
        DoLog " !! Unable to open/read $inputFile or any file matching $regEx -- exiting"
        exit 1
    } else {
      # if an AP_HED file exists, rename it to AP_IMPORT
      DoLog " --> Found $apInputFile"
      
      $fullOrigFilePath = $PATH + $apInputFile
      $fullImportFilePath = $inputFile

      try {  # rename the file
        Move-Item -Path $fullOrigFilePath -Destination $fullImportFilePath -Force -ErrorAction Stop
        DoLog " --> Renamed '$fullOrigFilePath' to '$fullImportFilePath'"
      } catch {
        DoLog "!! Unable to move '$fullOrigFilePath' to '$fullImportFilePath': $($_.Exception.Message)"
        exit 1
      }
    }
} else {
  DoLog " --> Existing AP_IMPORT.txt file found"
}

# Read the content of the input file
$content = Get-Content -Path $inputFile

DoLog " --> Processing $inputFile ..."
 
# Process each line
$modifiedContent = $content | ForEach-Object {
    $line = $_
    # @ is used to indicate a new record. so 1 per original line
    $newLine = "@" + ""
    $currentIndex = 0

    foreach ($col in $columns) {
        if ($col -le $line.Length) {
            $newLine += $line.Substring($currentIndex, $col - $currentIndex) + "`r`n"
            $currentIndex = $col
        } else {
            $newLine += $line.Substring($currentIndex)
            break
        }
    }

    if ($currentIndex -lt $line.Length) {
        $newLine += $line.Substring($currentIndex)
    }

    $newLine
}

DoLog " --> Writing new file to $outputFile ..."

# Write the modified content to the output file
$modifiedContent | Set-Content -Path $outputFile

# move the input file to the backup folder with a date stamp
$dateStamp      = Get-Date -Format "yyyyMMdd"
$backupDir      = $PATH + "BACKUP\"
$inputFileName  = [System.IO.Path]::GetFileNameWithoutExtension($inputFile)
$inputFileExt   = [System.IO.Path]::GetExtension($inputFile)
$backupFileName = "$inputFileName-$dateStamp$inputFileExt"
$backupPath     = [System.IO.Path]::Combine($backupDir, $backupFileName)

DoLog " --> Moving file to $backupPath ..."

Move-Item -Force -Path $inputFile -Destination $backupPath

$stamp = Get-Date

DoLog "Preprocessor Finished: $stamp"