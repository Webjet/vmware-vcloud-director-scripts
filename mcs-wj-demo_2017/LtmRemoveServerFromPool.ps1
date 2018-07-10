### Sample powershell script for working with the F5-LTM module 
###
### This script will create a node and add it to an existing pool
###
### Parameters:
### ltmAddress		- IP Address of the LTM
### apiUsername		- Username for accessing REST API
### apiPassword		- Password for accessing REST API 
### ltmPoolName		- Existing pool name
### ltmNodeAddress	- IP Address of node to add
### ltmPortNumber	- Port to add to the pool member
###
Param(
	[parameter(Mandatory=$True)]
	$ltmAddress,
	[parameter(Mandatory=$True)]
	$apiUsername,
	[parameter(Mandatory=$True)]
	$apiPassword,
	[parameter(Mandatory=$True)]
	$ltmPoolName,
	[parameter(Mandatory=$True)]
	$ltmNodeAddress,
	[parameter(Mandatory=$True)]
	$ltmPortNumber
)

$ProgressPreference = 'SilentlyContinue'

# Import the F5-LTM module
Try {
	Import-Module F5-LTM -ErrorAction Stop
} Catch {
	Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
} Finally {
	Write-Output "Imported F5-LTM Module"
}

# Create login credentials
$secPassword = ConvertTo-SecureString $apiPassword -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential $apiUsername, $secPassword

# Login to the LTM REST API
Try {
	New-F5Session -LTMName $ltmAddress -LTMCredentials $credentials -ErrorAction Stop
} Catch {
	Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
} Finally {
	Write-Output "Logged into F5-LTM $($ltmAddress)"
}

# Check to see if node exists:
Try {
	$node = Get-Node -Address $ltmNodeAddress
} Catch {
	Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}
If ( $node ) {
	Write-Output "Found node $($node.Name) ($($node.Address))"
} Else {
	Write-Output "Node not found .. $ltmNodeAddress"
	Exit(1)
}

# Check for our pool member, and if existing, remove:
Try {
	$poolMember = Get-PoolMember -PoolName $ltmPoolName -Name "$($ltmNodeAddress):$($ltmPortNumber)" -ErrorAction Stop
} Catch {
	Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}
If ( $poolMember ) {
	Write-Output "Found existing pool member $($poolMember.Name) in pool $($ltmPoolName)"
	Try {
		Remove-PoolMember -PoolName $ltmPoolName -Name "$($ltmNodeAddress):$($ltmPortNumber)" -ErrorAction Stop -Confirm:$False
	} Catch {
		Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
		Write-Output "Unable to remove $($ltmNodeAddress):$($ltmPortNumber) from pool $($ltmPoolName)"
		Exit(1)
	}	
} Else {
	Write-Output "Pool member not found $($ltmNodeAddress):$($ltmPortNumber) in pool $($ltmPoolName)"
	Exit(1)
}

Write-Output "Pool member $($poolMember.Name) Removed"
Exit(0)
