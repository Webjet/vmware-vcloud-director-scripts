#Domain and Customisation Script Variables:
$joinDomainName = "wjhack.local"
$joinDomainUserName = "Administrator"
$joinDomainUserPassword = ""
$joinMachineObjectOU = "OU=Servers,DC=wjhack,DC=local" # CN=Computers is not an OU
$joinDomain = $true
$vmname = 'WJ-TEST-VM03'

#Guest Customization::
Try {
	write-host "Setting Guest Customization settings:"
    #$vm = get-civm -vapp $vappNameNew
    $vmCustomization = $vmname.ExtensionData.GetGuestCustomizationSection()
	$vmCustomization.Enabled = $true
	$vmCustomization.ChangeSid = $true
	write-host "Join Domain Value is $($joinDomain)"
	$vmCustomization.JoinDomainEnabled = $joinDomain
	$vmCustomization.UseOrgSettings = $false
	if ($joinDomain) 
	{
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