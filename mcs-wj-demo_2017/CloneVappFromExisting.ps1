### clone_vapp v1
###.\clone_vapp_v1.ps1 -ciServer "vcloud.macquarieview.com" -orgVdc "M2SVC20637001" -orgname "Webjet_Marketing_Pty_Ltd_42809_SVC" -apiusername "devadmin" -apipassword "P@ssw0rd" -vappNameOrig "WJ-DEV-NODE01" -vappNameNew "WJ-DEV-NODE03"  \
-orgVdcNetworkName "V2777-DEV1-M2VLN20637001" -vappIp "172.28.85.36" 
### V2777-DEV1-M2VLN20637001 M2SVC20637001 172.28.85.254 Direct

###Param(
    #[parameter(Mandatory=$true)]
    #$ciServer,
    #[parameter(Mandatory=$true)]
    #$vappNameOrig,
	#[parameter(Mandatory=$true)]
    #$vappNameNew,
    #[parameter(Mandatory=$true)]
    #$orgVdc,
	#[parameter(Mandatory=$true)]
    #$orgVdcNetworkName, 	# MUST have DNS server setting if $joinDomain = $true
    #[parameter(Mandatory=$true)]
    #$vappIp, 
    #[parameter(Mandatory=$true)]
    #$orgname,
    #[parameter(Mandatory=$true)]
    #$apiusername,
    #[parameter(Mandatory=$true)]
    #$apipassword
#)

$ciServer = $env:ciServer
$orgname = $env:orgname
$orgVdc = $env:orgVdc
$vappNameOrig = $env:vappNameOrig
$vappNameNew = $env:vappNameNew
$orgVdcNetworkName = $env:orgVdcNetworkName
$vappIp = $env:vappIp
$apiusername = $env:apiusername
$apipassword = $env:apipassword
if ( $env:joinDomain -eq "true" ) {
	$joinDomain = $true
} else {
	$joinDomain = $false
}

# Domain and Customisation Script Variables:
$joinDomainName = "wjhack.local"
$joinDomainUserName = "Administrator"
$joinDomainUserPassword = "P@ssw0rd"
$joinMachineObjectOU = "OU=Servers,DC=wjhack,DC=local" # CN=Computers is not an OU

#$customizationScript = "@echo off
#powershell.exe wget http://172.28.23.147/" + $vappName + ".txt -OutFile C:\Windows\Temp\" + $vappName + ".ps1
#powershell.exe C:\Windows\Temp\" + $vappName + ".ps1
#"
$customizationScript = ""

# $($vappname).ps1 example:
#Import-Module servermanager
#Add-WindowsFeature telnet-client

$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'
try{
	stop-transcript | out-null
}
Catch [System.InvalidOperationException]{}
Start-Transcript .\CloneVApp-$vappnameNew.txt -append -noclobber

# Attempt to load module:
Try {
	Add-PSSnapin VMware.VimAutomation.Cloud -ErrorAction SilentlyContinue
	[VMware.VimAutomation.Cloud.Views.CloudClient]::ApiVersionRestriction.ForceCompatibility("5.1")	
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
} Finally {
	Write-Host "Imported VCloud Module"
}

# Authenticate and connect to our endpoint:
# (Clear text password below is for lab/demo purpose only. Recommend hashing credential in production setup)
Try {
	Connect-CIServer -Server $ciServer -User $apiusername -Password $apipassword -Org $orgname | Out-Null
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
} Finally {
	Write-Host "Logged into $($ciServer)"
}

# Get our Target VDC:
Try {
	write-host "Getting Target VDC $($orgVdc)"
	$orgVdc = get-orgvdc $orgVdc
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}

# Clone Operation:
Try {
	write-host "Cloning source VApp $($vappNameOrig) to new VApp $($vappNameNew)"
	New-CIVApp -Name $vappNameNew -VApp $vappNameOrig | Out-Null
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Write-Host "Clone Operation Failed for $($vappNameNew)"
	Exit(1)
}

# Discard State:	
Try {
	write-host "Discarding the suspended state of cloned VApp"
	$targetvapp = Get-CIVApp -OrgVdc $orgVdc -Name $vappNameNew
	Set-CIVApp -VApp $targetvapp -DiscardSuspendedState -ErrorAction Stop | Out-Null
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

# Guest Customization::
Try {
	write-host "Setting Guest Customization settings:"
	$vm = get-civm -vapp $vappNameNew
	$vmCustomization = $vm.ExtensionData.GetGuestCustomizationSection()
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

# VM Name Change:
Try {
	write-host "Setting VM Name to $($vappNameNew)"
	$vm.extensiondata.name = $vappNameNew
	$vm.extensiondata.updateserverdata() | Out-Null
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}

# VM Network Details:
Try {
	write-host "Setting VM Network Details to IP $($vappIp)"
	$vmNetworkconnectionsection = $vm.ExtensionData.GetNetworkConnectionSection()
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
	$vm.ExtensionData.NeedsCustomization = $true
	$vm.extensiondata.updateserverdata() | Out-Null
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}

Try {
	write-host "Starting VM:"
	Start-CIvApp $targetvapp -confirm:$false | Out-Null
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Write-Host "VM failed to start"
	Exit(1)
}

Disconnect-CIServer -Server $ciServer -Confirm:$false

Stop-Transcript
### END
