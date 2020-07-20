#Logging initializations: change as you deem fit
$LogDir = ".\logs"
$ilogFile = "Audit.log"

$LogPath = $LogDir + '\' + $iLogFile

#Load Logger Function - relative path
# Function to Write into Log file
Function Write-Log {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False)]
        [ValidateSet("INFO", "WARN", "ERROR", "FATAL", "DEBUG")]
        [String]
        $Level = "INFO",

        [Parameter(Mandatory = $True)]
        [string]
        $Message,

        [Parameter(Mandatory = $False)]
        [string]
        $logfile
    )

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "$Stamp $Level $Message"
    if ($logfile) {
        Add-Content $logfile -Value $Line
    }
    else {
        Write-Output $Line
    }
}
#Checking for existence of logfolders and files if not create them.
if (!(Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType directory
    New-Item -Path $LogDir -Name $iLogFile -ItemType File
}
else {
    Write-Host "$LogDir exists" 
        
}

$confFile = ".\config.json"

if (!(Test-Path $confFile)) {
    Write-Log ERROR "The $confFile file must exist in the script's path. Exiting " $LogPath
    Write-Host "missing $confFile"
    break
}

$confFileContent = (Get-Content $confFile -Raw) | ConvertFrom-Json

# Give preferenece to env varible 

# APPDYNAMICS_CONTROLLER_URL 
# APPDYNAMICS_OAUTH_TOKEN
# APPDYNAMICS_NODE_AVAILABILITY_THRESHOLD
# APPDYNAMICS_EXECUTION_FREQUENCY
# APPDYNAMICS_TARGET_APPLICATIONS
# APPDYNAMICS_EXECUTE_ONCE_OR_CONTINUOUS

$controllerURL = ${env:APPDYNAMICS_CONTROLLER_URL}
$OAuthToken = ${env:APPDYNAMICS_OAUTH_TOKEN}
$apps = ${env:APPDYNAMICS_TARGET_APPLICATIONS}
$ThresholdInMintues = ${env:APPDYNAMICS_NODE_AVAILABILITY_THRESHOLD}
$ExecutionFrequencyInMinutes = ${env:APPDYNAMICS_EXECUTION_FREQUENCY}
$JobType = ${env:APPDYNAMICS_EXECUTE_ONCE_OR_CONTINUOUS}

if ([string]::IsNullOrEmpty($controllerURL)) {
    #default to config.file 
    $controllerURL = $confFileContent.ConfigItems | Where-Object { $_.Name -eq "ControllerURL" } | Select-Object -ExpandProperty Value
}

if ([string]::IsNullOrEmpty($OAuthToken)) {
    #default to config.file 
    $OAuthToken = $confFileContent.ConfigItems | Where-Object { $_.Name -eq "OAuthToken" } | Select-Object -ExpandProperty Value
}

if ([string]::IsNullOrEmpty($apps)) {
    #default to config.file 
    $apps = $confFileContent.ConfigItems | Where-Object { $_.Name -eq "ApplicationList" } | Select-Object -ExpandProperty Value
}

if ([string]::IsNullOrEmpty($ThresholdInMintues)) {
    #default to config.file 
    $ThresholdInMintues = $confFileContent.ConfigItems | Where-Object { $_.Name -eq "NodeAvailabilityThresholdInMinutes" } | Select-Object -ExpandProperty Value
}

if ([string]::IsNullOrEmpty($ExecutionFrequencyInMinutes)) {
    #default to config.file 
    [int]$ExecutionFrequencyInMinutes = $confFileContent.ConfigItems | Where-Object { $_.Name -eq "ExecutionFrequencyInMinutes" } | Select-Object -ExpandProperty Value
}
else {
    [int]$ExecutionFrequencyInMinutes = ${APPDYNAMICS_EXECUTION_FREQUENCY}
}

if ([string]::IsNullOrEmpty($JobType)) {
    #default to config.file 
    $JobType = $confFileContent.ConfigItems | Where-Object { $_.Name -eq "ExecuteOnceORContinuous" } | Select-Object -ExpandProperty Value
}


if ([string]::IsNullOrEmpty($controllerURL) -or [string]::IsNullOrEmpty($OAuthToken) -or [string]::IsNullOrEmpty($apps) -or [string]::IsNullOrEmpty($ThresholdInMintues) -or [string]::IsNullOrEmpty($ExecutionFrequencyInMinutes)) {
  
    Write-Host "One or more required parameter value is/are missing" 

    Write-Host " Controller URL: $controllerURL"
    Write-Host " OAuthToken: $OAuthToken"
    Write-Host " Target Applications : $apps"
    Write-Host " ThresholdInMintues : $ThresholdInMintues"
    Write-Host " ExecutionFrequencyInMinutes : $ExecutionFrequencyInMinutes"

    Write-Error 'Exiting..due to empty or null paramter values ' -ErrorAction Stop

}

#default ExecuteOnceORContinuous to Once
if ([string]::IsNullOrEmpty($JobType)){
    $JobType = "Once"
}

#trim last / in the controller url if provided by mistake 
$controllerURL = $controllerURL.trim('/')

[int]$SleepTime = $ExecutionFrequencyInMinutes * 60 
Write-Host $SleepTime

if ($SleepTime -gt 2147483) {
    Write-Host "The ExecutionFrequencyInMinutes value, $ExecutionFrequencyInMinutes ($SleepTime)secs is greater than the maximum allowed value of 35791 minutes in Powershell." -ForegroundColor RED
    break
}
$JWTToken = "Bearer $OAuthToken"
$historicalEndPoint = "$controllerURL/controller/rest/mark-nodes-historical?application-component-node-ids"
$headers = @{Authorization = $JWTToken }
While ($true) {
    ForEach ($application in $apps.Split(",")) {
        $msg = "Proccessing $application application"
        Write-Host $msg
        $getNodesEndPoint = "$controllerURL/controller/rest/applications/" + $application + "/nodes"  
        try {
            [xml] $XMLData = Invoke-RestMethod -Uri $getNodesEndPoint -Method Get -Headers $headers 
        }
        catch {
            Write-Warning "$($error[0])"
            Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
            Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
            Write-Host "ErrorMessage:" $_.Exception.Message
        }
        ForEach ($node in $XMLData.nodes.node) {
            $nname = $node.name
            $msg = "Checking $nname"
            Write-Host $msg
            $reapMe = $true
            $metricPath = "Application Infrastructure Performance|" + $node.tierName + "|Individual Nodes|" + $node.name + "|Agent|App|Availability"
            try {
                $nodeAvailability = "$controllerURL/controller/rest/applications/$application/metric-data?metric-path=$metricPath&time-range-type=BEFORE_NOW&duration-in-mins=$ThresholdInMintues&output=JSON&rollup=true"
                $metrics = Invoke-RestMethod -Uri $nodeAvailability -Method Get -ContentType "application/json" -Headers $headers
                if ($metrics.metricValues.sum -gt 0) {
                    $reapMe = $false
                }
                Write-Host $reapMe
            }
            catch {
                Write-Host "Exception occured whilst checking availability for node: " $node.name
            }
        
            if ($reapMe) {
                $nname = $node.name
                $nid = $node.id
                try {
                    $response = Invoke-RestMethod -Uri "$historicalEndPoint=$nid" -Method POST -Headers $headers 
                    Write-Host "Response: " $response
                    if ($response -match $nid) { 
                        $msg = "Marked $nname($nid) in $application application as a historical node."
                        Write-Host $msg
                        Write-Log INFO $msg $LogPath
                    }
                    else {
                        Write-Host "Something went wrong, the node-name ($nid) is expected in the response from AppDynamics. The recieved response is: $response" -ForegroundColor red
                    }
        
                }
                catch {
                    Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
                    Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
                    Write-Host "ErrorMessage:" $_.Exception.Message
                }
            }
        }
        #End App split loop   
    }
    #End While Loop 
    Write-Host "Applying JobType instructon... you selected type = $JobType"
    if ($JobType -like "once" -or $JobType -like "one") {
        Write-Host "Completed. Stopping..".  
        Break Script
    
    }else{
        Write-Host "Going to sleep for $SleepTime before trying again"
        Start-Sleep -Seconds $SleepTime
    }
   
}
