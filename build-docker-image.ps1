[cmdletbinding()]
Param (
    [Parameter(Mandatory = $false)]
    [string]$tag,

    [Parameter(Mandatory = $false)]
    [string]$dockerHubHandle
)

if ($dockerHubHandle -eq "") {
    $dockerHubHandle = "appdynamicscx"
 }

 if ($tag -eq "") {
    $tag = "latest"
 }

#$IMAGE_NAME = "iogbole/machine-agent-windows-64bit"
$IMAGE_NAME = "$dockerHubHandle/mark-nodes-historical"

Write-Host "tag = $tag "
Write-Host "dockerHubHandle = $dockerHubHandle "

docker build --no-cache  -t ${IMAGE_NAME}:$tag . 

#docker run -d --env-file env.list.local ${IMAGE_NAME}:$tag 
#docker push ${IMAGE_NAME}:$tag 
#docker image inspect --format='' ${IMAGE_NAME}:$tag 
#docker exec -it container_id powershell 
#./build.ps1 -tag 1 -dockerHubHandle iogbole    