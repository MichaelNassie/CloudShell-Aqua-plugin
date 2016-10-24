param($variables, $tempDir, $aquaCallback)

$text = new-object System.Text.StringBuilder
$date = [System.DateTime]::Now
$text.AppendLine($date.ToLongDateString())
$text.AppendLine($date.ToLongTimeString())

echo "$text" > result.log

# the CS details necessaty in orderto start a session
$CloudshellServerPath = ""
# insert your CloudShell server path according to the following format: {hostname/IP}:{CloudShell portal configured port} for examples: "localhost:85", "10.20.1.1:80"
$csUsername
# insert a Cloudshell username with privilages. for example "admin"
$csPassword
# insert the password of an admin CS user. for example "admin"
$csDomain
# insert the logged in CloudShell domina. for example "Global"

foreach ($var in $variables)
{
  $varName = $var.Name
  $varValue = $var.Value
  
  if($varName -eq "$CloudshellServerPath"){
	$CloudshellServerPath  = $varValue
  }

  if($varName -eq "csUsername"){
	$csUsername  = $varValue
  }

  if($varName -eq "csPassword"){
	$csPassword  = $varValue
  }
  
  $aquaCallback.SendMessage("Variable: $varName : $varValue", [aqua.ProcessEngine.WebServiceProxy.ExecutionLogMessageType]::InformationalDebug, "PowerShell");
}

#############################################################################
# Login

$headers = @{}
$headers.Add("Content-Type", "application/json")
$body = '{"username" : "'+$csUsername+'","password" : "'+$csPassword+'","domain" : "'+$csDomain+'"}'
# hard coded: $body = '{"username" : "admin","password" : "admin","domain" : "Global"}'

$token = Invoke-RestMethod -URI 'http://'+ $CloudshellServerPath +'/API/Login' -Method PUT -Body $body -Headers $headers
# hard coded: $token = Invoke-RestMethod -URI 'http://10.20.6.109:82/API/Login' -Method PUT -Body $body -Headers $headers

$aquaCallback.SendMessage("Token: $token", [aqua.ProcessEngine.WebServiceProxy.ExecutionLogMessageType]::InformationalDebug, "PowerShell");

$authentication = "Basic $token"

$headers = @{}
$headers.Add("Content-Type", "application/json")
$headers.Add("Accept", "application/json")
$headers.Add("Authorization", "$authentication")

# "------------ List Blueprints ------------"
# Invoke-RestMethod -URI 'http://10.20.6.109:82/API/v1/Blueprints' -Method GET -Headers $headers

# "------------ List Sandboxes ------------"
# Invoke-RestMethod -URI 'http://10.20.6.109:82/API/v1/Sandboxes' -Method GET -Headers $headers 

#########################################################
# "------------ Stopping Sandbox ------------"

$file = $tempDir + "\..\ID.txt"
$identifier = Get-Content $file -First 1
$aquaCallback.SendMessage("Stopping Sandbox with ID: $identifier", [aqua.ProcessEngine.WebServiceProxy.ExecutionLogMessageType]::InformationalDebug, "PowerShell");

$response = Invoke-RestMethod -URI "http://'+ $CloudshellServerPath +'/API/v1/Sandboxes/$identifier" -Method GET -Headers $headers
# hard coded : response = Invoke-RestMethod -URI "http://10.20.6.109:82/API/v1/Sandboxes/$identifier" -Method GET -Headers $headers
$state = $response.state
$aquaCallback.SendMessage("Sandbox is in State: $state", [aqua.ProcessEngine.WebServiceProxy.ExecutionLogMessageType]::InformationalDebug, "PowerShell");

if($state -match "Ended"){
	$aquaCallback.SendMessage("Nothing to do", [aqua.ProcessEngine.WebServiceProxy.ExecutionLogMessageType]::InformationalDebug, "PowerShell");
	return "Ready"
} else {
	Invoke-RestMethod -URI "http://'+ $CloudshellServerPath +'/API/v1/sandboxes/$identifier/stop" -Method POST -Headers $headers
	# hard coded : Invoke-RestMethod -URI "http://10.20.6.109:82/API/v1/sandboxes/$identifier/stop" -Method POST -Headers $headers
}

# "------------ Waiting for Sandbox TearDown ------------"

$unfinished = 1
while ($unfinished) {
	$response = Invoke-RestMethod -URI "http://10.20.6.109:82/API/v1/Sandboxes/$identifier" -Method GET -Headers $headers
	$state = $response.state
	$aquaCallback.SendMessage("State: $state", [aqua.ProcessEngine.WebServiceProxy.ExecutionLogMessageType]::InformationalDebug, "PowerShell");
	if($state -match "Ended"){
		$aquaCallback.SendMessage("Sandbox terminated with State: $state", [aqua.ProcessEngine.WebServiceProxy.ExecutionLogMessageType]::InformationalDebug, "PowerShell");
		$unfinished = 0
	} else {
		Start-Sleep -Seconds 10
	}
}
$state = $response.state
$aquaCallback.SendMessage("Sandbox teardown has finished with State: $state", [aqua.ProcessEngine.WebServiceProxy.ExecutionLogMessageType]::InformationalDebug, "PowerShell");

# Return status of script execution. One of: Ready, Blocked, Fail, Aborted
return "Ready"
