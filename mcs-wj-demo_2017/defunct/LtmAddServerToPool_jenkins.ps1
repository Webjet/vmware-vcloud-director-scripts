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
#Param(
#	[parameter(Mandatory=$True)]
#	$ltmAddress,
#	[parameter(Mandatory=$True)]
#	$apiUsername,
#	[parameter(Mandatory=$True)]
#	$apiPassword,
#	[parameter(Mandatory=$True)]
#	$ltmPoolName,
#	[parameter(Mandatory=$True)]
#	$ltmNodeAddress,
#	[parameter(Mandatory=$True)]
#	$ltmPortNumber
#)

$ltmAddress = $env:ltmAddress
$apiUsername = $env:ltmUsername
$apiPassword = $env:ltmPassword
$ltmPoolName = $env:ltmPoolName
$ltmNodeAddress = $env:ltmNodeAddress
$ltmPortNumber = $env:ltmPortNumber

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

# Create a new node if it does not already exist
Try {
	$node = Get-Node -Address $ltmNodeAddress
} Catch {
	Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}
If ( $node ) {
	Write-Output "Using existing node $($node.Name) ($($node.Address)) as it already exists"
} Else {
	Try {
		# The node name will be the address
		New-Node -Address $ltmNodeAddress -Name $ltmNodeAddress -ErrorAction Stop
		$node = Get-Node -Address $ltmNodeAddress -ErrorAction Stop
	} Catch {
		Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
		Exit(1)
	} Finally {
		Write-Output "Created new node $($node.Name) ($($node.Address))"
	}
}

# Create a new pool member if it does not already exist
Try {
	$poolMember = Get-PoolMember -PoolName $ltmPoolName -Name "$($ltmNodeAddress):$($ltmPortNumber)" -ErrorAction Stop
} Catch {
	Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
}
If ( $poolMember ) {
	Write-Output "Using existing pool member $($poolMember.Name) as it already exists"
} Else {
	Try {
		$poolMember = Add-PoolMember -Address $ltmNodeAddress -PoolName $ltmPoolName -PortNumber $ltmPortNumber -Status 'Enabled' -ErrorAction Stop
	} Catch {
		Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
		Exit(1)
	} Finally {
		Write-Output "Created new pool member $($poolMember.Name) in pool $($ltmPoolName)"
	}
}

$i = 0
Do {
	Start-Sleep -s 10 -ErrorAction SilentlyContinue
	$poolMember = Get-PoolMember -PoolName $ltmPoolName -Name $poolMember.Name
	if ($i++ -gt 6) {
		Write-Output "Pool member $($poolMember.Name) taking to long for state to enter come up"
		Exit(1)
	}
} while ($poolMember.State -ne "up")

Write-Output "Pool member $($poolMember.Name) is now up"
Exit(0)
