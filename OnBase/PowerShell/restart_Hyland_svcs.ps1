<#
  Hyland OnBase service restart

  This script is used to restart the various service daemons 
  running on the Process Server
#>

# log file info
$sys_name = $(gc env:computername)
$log_file = "C:\BatchFiles\logs\onbase_services.log"

# parts for the email message
$eSMTP = "smtp.uaf.edu"
$eTO   = "OnBase Admin Team <ua-osact-team@alaska.edu>"
$eFrom = "UA OnBase Mailer Daemon<no-reply@alaska.edu>"
$eSubj = "[ONBASE] " + $sys_name + " Service Restart"
$eBody = "Hello,`n The service restart is done.`n"

# Services to restart
$Hyland_names = @( 
    "Hyland Aut",                                                   # Hyland Autofill Service -- named 'AF'
    "Hyland DIP",                                                   # Hyland service for running the DIPs
    "Hyland Mul",                                                   # Hyland Multipurpose Service ( queues, commits, etc)
    "Hyland Unity Scheduler Service: Distribution_UnityScheduler",  # Hyland Service for the Distribution task group 
    "Hyland Unity Scheduler Service: System_UnityScheduler",        # Hyland Service for the System task group
    "Hyland Unity Scheduler Service: WorkFlow_UnityScheduler",      # Hyland Service for the Workflow task group
    "Hyland Unity Scheduler Service: Admin"                         # Hyland Service for the Admin task group
)

# array for service objects
$service_array = @()

# ---- Functions
Function DoLog {
    Param ([string]$message)

    # Build status message line
    $ts = (Get-Date).toString("dd MMM yyyy @ HH:mm")
    $out = "[ $ts ] $message `n"

    # console message
    #Write-Host $out
    #add to log
    Add-content $log_file -value $out
}

# ---- Main

# Log the start
DoLog "Service Restart begin: ... `n"

# get the service objects
foreach ( $name in $Hyland_names) {
  $service_array += Get-Service -Name $name
}

# iterate through the services and restart them
foreach ($svc in $service_array) {

  DoLog "Working on Service: '$($svc.Name)' Status: $($svc.Status)"
  $eBody += "Restarted Service: '$($svc.Name)' `n"

  # stop the service (if not already stopped)
  if($svc.State -ne "Stopped") {
    Stop-Service $svc.Name 

    # wait until it is stopped, or 30 seconds
    $svc.WaitForStatus('Stopped', '00:00:30')
  }

  DoLog " - '$($svc.Name)' is stopped"
   
  # re-start
  Start-Service $svc

  # wait until it is stopped, or 30 seconds
  $svc.WaitForStatus('Running', '00:00:30')

  # log the actual new status
  DoLog " - '$($svc.Name)' is now $($svc.Status)"
}

DoLog " - All requested services completed `n---------------------------------------`n"

# send out the confirmation email
Send-MailMessage -SmtpServer $eSMTP -From $eFrom -To $eTO -Subject $eSubj -Body $eBody