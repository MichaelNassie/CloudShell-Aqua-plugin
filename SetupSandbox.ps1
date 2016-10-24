param($variables, $tempDir, $aquaCallback)

$text = new-object System.Text.StringBuilder
$date = [System.DateTime]::Now
$text.AppendLine($date.ToLongDateString())
$text.AppendLine($date.ToLongTimeString())

echo "$text" > result.log

$id = ""
$name = ""
$duration = "PT4H1M"
foreach ($var in $variables)
{
  $varName = $var.Name
  $varValue = $var.Value
  
  if($varName -eq "ID"){
	$id = $varValue
  }
  
  if($varName -eq "Name"){
	$name = $varValue
  }
  
  if($varName -eq "Duration"){
	$duration = $varValue
  }
  $aquaCallback.SendMessage("Variable: $varName : $varValue", [aqua.ProcessEngine.WebServiceProxy.ExecutionLogMessageType]::InformationalDebug, "PowerShell");
}

#############################################################################
# Login

$headers = @{}
$headers.Add("Content-Type", "application/json")
$body = '{"username" : "admin","password" : "admin","domain" : "Global"}'

$token = Invoke-RestMethod -URI 'http://10.20.6.109:82/API/Login' -Method PUT -Body $body -Headers $headers

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
# "------------ Starting blueprint ------------"

$identifier = $id
# $duration = "PT4H1M" # set above
$name = "aqua-Testing-Sandbox"

$body = '{"duration" : "'+$duration+'","name" : "'+$name+'"}'

$headers = @{}
$headers.Add("Content-Type", "application/json")
$headers.Add("Accept", "application/json")
$headers.Add("Authorization", "$authentication")

$response = Invoke-RestMethod -URI "http://10.20.6.109:82/API/v1/Blueprints/$identifier/start" -Method POST -Headers $headers -Body $body

$file = $tempDir + "\..\ID.txt"

$sandbox_id = $response.id
$sandbox_id > $file

$aquaCallback.SendMessage("Sandbox is initiated. ID: $sandbox_id", [aqua.ProcessEngine.WebServiceProxy.ExecutionLogMessageType]::InformationalDebug, "PowerShell");

# "------------ Waiting for Sandbox ------------"

$unfinished = 1
while ($unfinished) {
	$response = Invoke-RestMethod -URI "http://10.20.6.109:82/API/v1/Sandboxes/$sandbox_id" -Method GET -Headers $headers
	$state = $response.state
	$aquaCallback.SendMessage("State: $state", [aqua.ProcessEngine.WebServiceProxy.ExecutionLogMessageType]::InformationalDebug, "PowerShell");
	if($response.state -match "Active" -Or $response.state -match "Error"){
		if($response.state -match "Error"){
			$aquaCallback.SendMessage("State: $state", [aqua.ProcessEngine.WebServiceProxy.ExecutionLogMessageType]::ExecutionError, "PowerShell");
		}
		$unfinished = 0
	} else {
		Start-Sleep -Seconds 10
	}
}
$state = $response.state
$aquaCallback.SendMessage("Sandbox setup has finished with State: $state", [aqua.ProcessEngine.WebServiceProxy.ExecutionLogMessageType]::InformationalDebug, "PowerShell");

Start-Sleep -Seconds 20

######################################################
$aquaCallback.AddExecutionAttachment($file);

# Return status of script execution. One of: Ready, Blocked, Fail, Aborted
if($state -match "Error"){
	return "Fail"
} else {
	return "Ready"
}
