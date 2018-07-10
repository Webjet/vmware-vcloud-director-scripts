### Sample Powershell Script for Self-service vCloud Director Automation
###
### Author
###  Mark Jiang (mjiang@macquarieCloudServices.com)
###
### Version
###  1.2
###
### ChangeLog
###  1.0 initial draft
###  1.1 recommend credential hashing
###  1.2 update vm template requirement
###
### Overview 
###  This script is to showcase vCloud Director's automation capability delivered via SDK & API to MCS Self-Managed VDC:
###   deploy a Windows 2012 VM from a template
###   join an existing AD domain
###   kick off a post-build script for application install & configuration
###
### Intended audience
###  Architecture/DevOps teams
###
### Requirements
###  Powershell scripting skill
###  Familiarity with VCD concepts, e.g. Org, Vdc, Vapp, Vm, VdcNetwork, Storage Policy, etc. and their presentation in VMware PowerCLI
###  VMware PowerCLI for Tenants with vCloud Director component installed on Windows workstation where the script will run
###  Existing Windows 2012R2 VM Template in Customer VCD Catalog
###   VMware Tools pre-installed
###   Catalog > vApp Tempalte > VM > Properties > Guest OS Customization tab > Enable guest customization = ticked
###   at least one VMXNET3 vNIC
###  (Optional) Existing AD domain
###   Domain controllers accessible from target VdcNetwork
###   Domain controller ips set in VdcNetwork as DNS servers by MCS
###  (Optional) Existing script/software repo web server
###  All parameters mandated by the script be worked out (consult MCS if needs clarification or assistance)
###  All constants (such as AD domain credential) in script be updated as per target environment
###
### Sample usage
###  contoso-dc01 (base OS for Domain Controller)
###   .\DeployVappSvc.ps1 -ciServer vcloudxxx.macquarieview.com -vappName contoso-dc01 -computername cts-dc01 -orgVdc MxSVCxxxxxxxx -tmplCatalog "Customer_xxxxx_SVC_Catalog" -vappTmpl W2012R2STD -orgVdcNetworkName Customer_xxxxx-Web-MxVXLxxxxxxxx -vappIp 172.xx.xxx.xxx -vappCpu 2 -vappMem 4096 -vappDisk 40960 -storageProfileName MT-VNXxxx-T700-PVDCxxxx -joinDomain $false -orgname "Contoso_xxxxx_SVC" -apiusername ctsadmin -apipassword xxxxxxxx
###  contoso-app01 (member app server)
###   .\DeployVappSvc.ps1 -ciServer vcloudxxx.macquarieview.com -vappName contoso-app01 -computername cts-app01 -orgVdc MxSVCxxxxxxxx -tmplCatalog "Customer_xxxxx_SVC_Catalog" -vappTmpl W2012R2STD -orgVdcNetworkName Customer_xxxxx-Web-M1VXLxxxxxxxx -vappIp 172.xx.xxx.xxx -vappCpu 2 -vappMem 4096 -vappDisk 40960 -storageProfileName MT-VNXxxx-T700-PVDCxxxx -joinDomain $true  -orgname "Contoso_xxxxx_SVC" -apiusername ctsadmin -apipassword xxxxxxxx
###

#Param(
    #[parameter(Mandatory=$true)]
    ##$ciServer,
    #[parameter(Mandatory=$true)]
    #$vappName,
    #[parameter(Mandatory=$true)]
    #$computername, 		# Maximum 15 characters for Windows
    #[parameter(Mandatory=$true)]
    #$orgVdc,
    #[parameter(Mandatory=$true)]
    #$tmplCatalog,
    #[parameter(Mandatory=$true)]
    #$vappTmpl, 			# MUST have vmware tools pre-installed & at least one VMXNET3 vnic
    #[parameter(Mandatory=$true)]
    #$orgVdcNetworkName, 	# MUST have DNS server setting if $joinDomain = $true
    #[parameter(Mandatory=$true)]
    #$vappIp, 			# MUST be within ip range defined under orgVdcNetwork
    #[parameter(Mandatory=$true)]
    #[int]$vappCpu, 		# number of vcore
    #[parameter(Mandatory=$true)]
    #[int]$vappMem, 		# unit MB = GB * 1024
    #[parameter(Mandatory=$true)]
    #[string]$vappDisk, 		# unit MB = GB * 1024
    #[parameter(Mandatory=$true)]
    #$storageProfileName,
    #[parameter(Mandatory=$true)]
    #$joinDomain,
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
$vappName = $env:vappName
$computername = $env:computername
$tmplCatalog = $env:tmplCatalog
$vappTmpl = $env:vappTmpl
$orgVdcNetworkName = $env:orgVdcNetworkName
$vappIp = $env:vappIp
$vappCpu = $env:vappCpu
$vappMem = $env:vappMem
$vappDisk = $env:vappDisk
$storageProfileName = $env:storageProfileName
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
Start-Transcript .\DeployVappSvc-$vappname.txt -append -noclobber

# Attempt to load module:
Try {
	Add-PSSnapin VMware.VimAutomation.Cloud -ErrorAction SilentlyContinue
	[VMware.VimAutomation.Cloud.Views.CloudClient]::ApiVersionRestriction.ForceCompatibility("5.1")	
} Catch {
	Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
} Finally {
	Write-Output "Imported VCloud Module"
}

# Authenticate and connect to our endpoint:
# (Clear text password below is for lab/demo purpose only. Recommend hashing credential in production setup)
Try {
	Connect-CIServer -Server $ciServer -User $apiusername -Password $apipassword -Org $orgname | Out-Null
} Catch {
	Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
} Finally {
	Write-Output "Logged into $($ciServer)"
}

# Start our VApp Creation:
write-host "Preparing to create new VApp $($vappname)"
Try {
	$orgVdc = get-orgvdc $orgVdc
} Catch {
	Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Write-Output "Unable to find VDC $($orgVdc)"
	Exit(1)
}

# Find Vapp Template:
Try {
	$vappTemplate = Get-CIVAppTemplate $vappTmpl -Catalog (Get-catalog $tmplCatalog)
} Catch {
	Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Write-Output "Failed to find requested Vapp Template $($vappTmpl) from $($tmplCatalog)"
	Exit(1)
}

# Find Storage Profile:
Try {
	$storageProfile = Search-Cloud -QueryType OrgVdcStorageProfile -Name $storageProfileName
} Catch {
	Write-Output "Unable to find storage profile $($storageProfileName)"
	Exit(1)
}

# Instantiation Parameters:
Try {
	Write-Output "Initialising Instantiation Parameters"
	$instParams = new-object VMware.VimAutomation.Cloud.Views.InstantiateVAppTemplateParams
	$instParams.InstantiationParams = new-object VMware.VimAutomation.Cloud.Views.InstantiationParams
	$instParams.name = $vappName
	$instParams.Deploy = $false
	$instParams.PowerOn = $false
	$instParams.Source = $vappTemplate.href
	$instParams.AllEULAsAccepted = $true
	$vappTemplateVms = $vappTemplate.extensiondata.children.vm
	foreach ($vappTemplateVm in $vappTemplateVms) {
		$SourcedVmInstantiationParams = new-object VMware.VimAutomation.Cloud.Views.SourcedVmInstantiationParams
		$SourcedVmInstantiationParams.Source = $vappTemplateVm.href
		$SourcedVmInstantiationParams.Source.Name = $vappTemplateVm.Name
		$SourcedVmInstantiationParams.StorageProfile = $storageProfile.href
		$instParams.SourcedVmInstantiationParams += $SourcedVmInstantiationParams
	}
} Catch {
	Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Write-Output "Failed to init our instantiation parameters"
	Exit(1)
}

# Create our VApp:
Try {
	Write-Output "Creating new VApp $($vappname)"
	$orgVdc.ExtensionData.InstantiateVAppTemplate($instParams) | Out-Null
	$vapp=Get-CIVApp $vappName
	while (($vapp.ExtensionData.Tasks.Task | where-object { $_.OperationName -eq "vdcInstantiateVapp" }).Status -in "running","queued" ) { $vapp=Get-CIVApp $vappName }
} Catch {
	Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Write-Output "Failed to create VApp"
	Exit(1)
} Finally {
	Write-Output "VApp Created Successfully"
}

# Set our VApp Network:
Try {
	write-host "Setting VApp Network"
	# Get the vapp network that existed in the template so we can delete it once the network adapter has been configured with the new network 
	$oldvappnetwork = Get-CIVappNetwork -VApp $vapp 
	$vappnetwork = new-object vmware.vimautomation.cloud.views.vappnetworkconfiguration
	$vappnetwork.NetworkName = $orgVdcNetworkName
	$vappnetwork.configuration = new-object vmware.vimautomation.cloud.views.networkconfiguration
	$vappnetwork.configuration.fencemode = "bridged"
	$vappnetwork.Configuration.ParentNetwork = New-Object vmware.vimautomation.cloud.views.reference
	$vappnetwork.Configuration.ParentNetwork.Href = ($orgVdc.ExtensionData.AvailableNetworks.Network | where {$_.name -eq $orgVdcNetworkName}).href
	$networkConfigSection = $vapp.ExtensionData.GetNetworkConfigSection()
	$networkConfigSection.networkconfig += $vappnetwork
	$networkConfigSection.updateserverdata() | Out-Null
} Catch {
	Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Write-Output "Failed to set VApp Network"
	Exit(1)
}

# Set our VApp Permissions:
Try {
	write-host "Setting VApp Permissions"
	$vappAccess = $vapp.ExtensionData.GetControlAccess()
	$vappAccess.IsSharedToEveryone = $true
	$vappAccess.EveryoneAccessLevel = "FullControl"
	$vapp.ExtensionData.ControlAccess($vappAccess) | Out-Null
} Catch {
	Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Write-Output "Failed to set VApp Permissions"
	Exit(1)
}

# Set our VApp Stop Permission:
Try {
	write-host "Setting VApp Stop Action"
	$vappStartupSection = $vapp.ExtensionData.GetStartupSection()
	$vmShutdown = $vappStartupSection.Item[0]
	$vmShutdown.StopAction = "guestShutdown"
	$vappStartupSection.updateserverdata() | Out-Null
} Catch {
	Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}

# Guest Customization::
Try {
	write-host "Setting Guest Customization settings:"
	$vm = get-civm -vapp $vappName
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
	$vmCustomization.ComputerName = $computername
	$vmCustomization.any = $null
	$vmCustomization.updateserverdata() | Out-Null
} Catch {
	Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Write-Output "Guest Customization failed"
	Exit(1)
}


# Set VM Name:
Try {
	write-host "Setting VM Name"
	$vm.extensiondata.name = $vappName
	$vm.extensiondata.updateserverdata()  | Out-Null
} Catch {
	Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}

# Set our VM Network, Manual for now, but IP Pool later to have vCloud track this resource:
Try {
	write-host "Setting our VM Network"
	$vmNetworkconnectionsection = $vm.ExtensionData.GetNetworkConnectionSection()
	$vmNetworkconnectionsection.PrimaryNetworkConnectionIndex = 0
	$vmNetworkconnectionsection.NetworkConnection[0].Network = $orgVdcNetworkName
	$vmNetworkconnectionsection.NetworkConnection[0].NeedsCustomization = $true
	$vmNetworkconnectionsection.NetworkConnection[0].IsConnected = $true
	#$vmNetworkconnectionsection.NetworkConnection[0].IpAddress = $vappIp
	$vmNetworkconnectionsection.NetworkConnection[0].IpAddressAllocationMode = "POOL"
	$vmNetworkconnectionsection.updateServerData() | Out-Null
	# Delete the old vapp network that existed in the template
	if ( $oldvappnetwork ) {
		Remove-CIVappNetwork -VAppNetwork $oldvappnetwork -Confirm:$False
	}
} Catch {
	Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}

# VM Resourcing:
Try {
	write-host "Setting VM Resource Sizes for CPU, Mem and Disk"
	$vmHardware = $vm.ExtensionData.GetVirtualHardwareSection()
	$vmCpu=$vmHardware.item | where {$_.ResourceType.value -eq 3}
	$cpuCount = New-object VMware.VimAutomation.Cloud.Views.CimUnsignedLong
	$cpuCount.Value = $vappCpu
	$vmCpu.VirtualQuantity = $cpuCount
	$vmMem=$vmHardware.item | where {$_.ResourceType.value -eq 4}
	$memSize = New-object VMware.VimAutomation.Cloud.Views.CimUnsignedLong
	$memSize.Value = $vappMem
	$vmMem.VirtualQuantity = $memSize
	$vmDisk=$vmHardware.item | where {$_.ResourceType.value -eq 17}
	$vmDisk.hostresource[0].AnyAttr[0].'#text' = $vappDisk
	$vmHardware.updateserverdata() | Out-Null
} Catch {
	Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Write-Output "Failed to set VM Resource"
	Exit(1)
}

# Shoot!:
Try {
	write-host "Starting VApp $($vappName)"
	Start-CIvApp $vapp -confirm:$false | Out-Null
} Catch {
	Write-Output "Failed to power on VApp"
	Exit(1)
}

Disconnect-CIServer -Server $ciServer  -Confirm:$false

Stop-Transcript
### END
