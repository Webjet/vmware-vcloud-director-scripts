#Clone Vapp
$vappNameNew = 'WJ-DEV-NODE03'
$vappNameOrig = 'WJ-DEV-NODE01'
$vmnamenew = 'WJ-DEV-VM03'

#Domain and Customisation Script Variables:
$joinDomain = $true
$joinDomainName = "wjhack.local"
$joinDomainUserName = "Administrator"
$joinDomainUserPassword = "******"
$joinMachineObjectOU = "OU=Servers,DC=wjhack,DC=local" # CN=Computers is not an OU

#VM Network variables
$vappIp = '172.28.85.36'
$orgVdcNetworkName = 'V2777-DEV1-M2VLN20637001'

# Clone Operation:
Try {
	write-host "Cloning source VApp $($vappNameOrig) to new VApp $($vappNameNew)"
	New-CIVApp -Name $vappNameNew -VApp $vappNameOrig | Out-Null
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Write-Host "Clone Operation Failed for $($vappNameNew)"
	Exit(1)
}

# Discard State: ###vApp "WJ-DEV-NODE03" does not have any suspended VMs
Try {
	write-host "Discarding the suspended state of cloned VApp"
	$targetvapp = Get-CIVApp -OrgVdc $orgVdc -Name $vappNameNew
	Set-CIVApp -VApp $targetvapp -DiscardSuspendedState -ErrorAction Ignore | Out-Null  ###vApp "WJ-DEV-NODE03" does not have any suspended VMs
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Write-Host "Discarding suspended state failed for $($vappNameNew)"
	Exit(1)
}

# Remove old network info from VApp:
Try { 
	write-host "Removing old network information from cloned VApp"
	Get-CIVAppNetwork -Vapp $targetvapp | Remove-CIVAppNetwork -Confirm:$False -ErrorAction Stop
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}

# Place new network into cloned Vapp:
Try { 
	write-host "Provisoning new network information $($orgVdcNetworkName) for cloned VApp"
	$vappnetwork = new-object vmware.vimautomation.cloud.views.vappnetworkconfiguration
	$vappnetwork.NetworkName = $orgVdcNetworkName
	$vappnetwork.configuration = new-object vmware.vimautomation.cloud.views.networkconfiguration
	$vappnetwork.configuration.fencemode = "bridged"
	$vappnetwork.Configuration.ParentNetwork = New-Object vmware.vimautomation.cloud.views.reference
	$vappnetwork.Configuration.ParentNetwork.Href = ($orgVdc.ExtensionData.AvailableNetworks.Network | where {$_.name -eq $orgVdcNetworkName}).href
	$networkConfigSection = $targetvapp.ExtensionData.GetNetworkConfigSection()
	$networkConfigSection.networkconfig += $vappnetwork
	$networkConfigSection.updateserverdata() | Out-Null
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}

#Guest Customization::
# If more than 1 VM, use array to specify which VM needs to be customized. 
Try {
	write-host "Setting Guest Customization settings:"
	$vm = get-civm -vapp $vappNameNew
	$vmCustomization = $vm[0].ExtensionData.GetGuestCustomizationSection()
	$vmCustomization.Enabled = $true
	$vmCustomization.ChangeSid = $true
	write-host "Join Domain Value is $($joinDomain)"
	$vmCustomization.JoinDomainEnabled = $joinDomain
	$vmCustomization.UseOrgSettings = $false
	if ($joinDomain) {
		$vmCustomization.DomainName = $joinDomainName
		$vmCustomization.DomainUserName = $joinDomainUserName
		$vmCustomization.DomainUserPassword = $joinDomainUserPassword
		$vmCustomization.MachineObjectOU = $joinMachineObjectOU
	}
	$vmCustomization.AdminPasswordEnabled = $true
	$vmCustomization.AdminPasswordAuto = $true
	$vmCustomization.CustomizationScript  = $customizationScript
	$vmCustomization.ComputerName = $vappNameNew
	$vmCustomization.any = $null
	$vmCustomization.updateserverdata() | Out-Null
} Catch {
	Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Write-Output "Guest Customization failed"
	Exit(1)
}

# VM Name Change:
Try {
	write-host "Setting VM Name to $($vappNameNew)"
	$vm[0].extensiondata.name = $vmnamenew
	$vm[0].extensiondata.updateserverdata() | Out-Null
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}

# VM Network Details:
Try {
	write-host "Setting VM Network Details to IP $($vappIp)"
	$vmNetworkconnectionsection = $vm[0].ExtensionData.GetNetworkConnectionSection()
	$vmNetworkconnectionsection.PrimaryNetworkConnectionIndex = 0
	$vmNetworkconnectionsection.NetworkConnection[0].Network = $orgVdcNetworkName
	$vmNetworkconnectionsection.NetworkConnection[0].NeedsCustomization = $true
	$vmNetworkconnectionsection.NetworkConnection[0].IsConnected = $true
	$vmNetworkconnectionsection.NetworkConnection[0].IpAddress = $vappIp
	$vmNetworkconnectionsection.NetworkConnection[0].IpAddressAllocationMode = "MANUAL"
	$vmNetworkconnectionsection.NetworkConnection[0].MACAddress = ""
	$vmNetworkconnectionsection.updateServerData() | Out-Null
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}

# VM Needs Customisation:
Try {
	$vm[0].ExtensionData.NeedsCustomization = $true
	$vm[0].extensiondata.updateserverdata() | Out-Null
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}

#Start VM
Try {
	write-host "Starting VM:"
	Start-CIvApp $targetvapp -confirm:$false | Out-Null
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Write-Host "VM failed to start"
	Exit(1)
}
