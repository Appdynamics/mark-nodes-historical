#Logging initializations: change as you deem fit
$LogDir = "C:\AppDynamics\Reaper"
$ilogFile = "Repaer.log"

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
if (!(test-path $LogDir)) {
    New-Item -Path $LogDir -ItemType directory
    New-Item -path $LogDir -name $iLogFile -Itemtype File
}
else {
    Write-Host "$LogDir exists" 
        
}

$confFile = ".\config.json"

if(!(test-path $confFile)) {
   Write-Log ERROR "The $confFile file must exist in the script's path. Exiting " $LogPath
   Write-Host "missing $confFile"
   break
}

$confFileContent = (Get-Content $confFile -Raw) | ConvertFrom-Json

$controllerURL = $confFileContent.ConfigItems | where-Object { $_.Name -eq "ControllerURL" } | Select-Object -ExpandProperty Value
$OAuthToken = $confFileContent.ConfigItems | where-Object { $_.Name -eq "OAuthToken" } | Select-Object -ExpandProperty Value
$apps = $confFileContent.ConfigItems | where-Object { $_.Name -eq "ApplicationList" } | Select-Object -ExpandProperty Value
$ThresholdInMintues = $confFileContent.ConfigItems | where-Object { $_.Name -eq "ThresholdInMintues" } | Select-Object -ExpandProperty Value

$JWTToken = "Bearer $OAuthToken"

$historicalurl = "$controllerURL/controller/rest/mark-nodes-historical"

$req = New-Object System.Net.WebClient
$req.Headers["Authorization"] = "$JWTToken"

ForEach($application in $apps.Split(",")) {
    $msg = "Proccessing $application application"
    Write-Host $msg
    Write-Log DEBUG $msg $LogPath
    $url = "$controllerURL/controller/rest/applications/" + $application + "/nodes"
    [xml] $nodesxml = $req.DownloadString($url)
    $req.DownloadString($url) | Out-File out.xml
    $headers = @{Authorization = $JWTToken}

    ForEach ($node in $nodesxml.nodes.node) {
        $nname = $node.name
        $msg = "Checking $nname"
        Write-Host $msg
        Write-Log DEBUG $msg $LogPath
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
            $reqparm = New-Object Collections.Specialized.NameValueCollection
            $reqparm.Add("application-component-node-ids", $node.id)
            $nname = $node.name
            $msg = "=Audit= Marking $nname historical="
            Write-Host $msg
            Write-Log DEBUG $msg $LogPath
            $req.UploadValues($historicalurl, "POST", $reqparm)   
        }
    }
}