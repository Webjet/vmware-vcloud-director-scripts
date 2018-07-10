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

Param(
    [parameter(Mandatory=$true)]
    $ciServer,
    [parameter(Mandatory=$true)]
    $vappName,
    [parameter(Mandatory=$true)]
    $computername, 		# Maximum 15 characters for Windows
    [parameter(Mandatory=$true)]
    $orgVdc,
    [parameter(Mandatory=$true)]
    $tmplCatalog,
    [parameter(Mandatory=$true)]
    $vappTmpl, 			# MUST have vmware tools pre-installed & at least one VMXNET3 vnic
    [parameter(Mandatory=$true)]
    $orgVdcNetworkName, 	# MUST have DNS server setting if $joinDomain = $true
    [parameter(Mandatory=$true)]
    $vappIp, 			# MUST be within ip range defined under orgVdcNetwork
    [parameter(Mandatory=$true)]
    [int]$vappCpu, 		# number of vcore
    [parameter(Mandatory=$true)]
    [int]$vappMem, 		# unit MB = GB * 1024
    [parameter(Mandatory=$true)]
    [string]$vappDisk, 		# unit MB = GB * 1024
    [parameter(Mandatory=$true)]
    $storageProfileName,
    [parameter(Mandatory=$true)]
    $joinDomain,
    [parameter(Mandatory=$true)]
    $orgname,
    [parameter(Mandatory=$true)]
    $apiusername,
    [parameter(Mandatory=$true)]
    $apipassword
)

### START
$joinDomainName = "example.com"
$joinDomainUserName = "Administrator"
$joinDomainUserPassword = "P@ssw0rd01"
$joinMachineObjectOU = "OU=Servers,DC=example,DC=com" # CN=Computers is not an OU
$customizationScript = "@echo off
powershell.exe wget http://172.28.23.147/" + $vappName + ".txt -OutFile C:\Windows\Temp\" + $vappName + ".ps1
powershell.exe C:\Windows\Temp\" + $vappName + ".ps1
"
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

try {
Add-PSSnapin VMware.VimAutomation.Cloud -ErrorAction SilentlyContinue
#[VMware.VimAutomation.Cloud.Views.CloudClient]::ApiVersionRestriction.ForceCompatibility("5.1")
# clear text password below is for lab/demo purpose only. recommend hashing credential in production setup
Connect-CIServer -Server $ciServer -User $apiusername -Password $apipassword -Org $orgname 

write-host "===new vapp==="
$orgVdc = get-orgvdc $orgVdc
$vappTemplate = Get-CIVAppTemplate $vappTmpl -Catalog (Get-catalog $tmplCatalog)
$storageProfile = Search-Cloud -QueryType OrgVdcStorageProfile -Name $storageProfileName
$instParams = new-object VMware.VimAutomation.Cloud.Views.InstantiateVAppTemplateParams
$instParams.InstantiationParams = new-object VMware.VimAutomation.Cloud.Views.InstantiationParams
$instParams.name = $vappName
# Guest Customization will fail if Deploy is $true 
$instParams.Deploy = $false
# Guest Customization will fail if PowerOn is $true
$instParams.PowerOn = $false
$instParams.Source = $vappTemplate.href
$instParams.AllEULAsAccepted = $true
$vappTemplateVms = $vappTemplate.extensiondata.children.vm
foreach ($vappTemplateVm in $vappTemplateVms)
{
	$SourcedVmInstantiationParams = new-object VMware.VimAutomation.Cloud.Views.SourcedVmInstantiationParams
	$SourcedVmInstantiationParams.Source = $vappTemplateVm.href
	$SourcedVmInstantiationParams.Source.Name = $vappTemplateVm.Name
	$SourcedVmInstantiationParams.StorageProfile = $storageProfile.href
	$instParams.SourcedVmInstantiationParams += $SourcedVmInstantiationParams
}
$orgVdc.ExtensionData.InstantiateVAppTemplate($instParams)
$vapp=Get-CIVApp $vappName
while (($vapp.ExtensionData.Tasks.Task | where-object { $_.OperationName -eq "vdcInstantiateVapp" }).Status -in "running","queued" ) { $vapp=Get-CIVApp $vappName }

write-host "===set vapp network==="
$vappnetwork = new-object vmware.vimautomation.cloud.views.vappnetworkconfiguration
$vappnetwork.NetworkName = $orgVdcNetworkName
$vappnetwork.configuration = new-object vmware.vimautomation.cloud.views.networkconfiguration
$vappnetwork.configuration.fencemode = "bridged"
$vappnetwork.Configuration.ParentNetwork = New-Object vmware.vimautomation.cloud.views.reference
$vappnetwork.Configuration.ParentNetwork.Href = ($orgVdc.ExtensionData.AvailableNetworks.Network | where {$_.name -eq $orgVdcNetworkName}).href
$networkConfigSection = $vapp.ExtensionData.GetNetworkConfigSection()
$networkConfigSection.networkconfig += $vappnetwork
$networkConfigSection.updateserverdata()

write-host "===set vapp permission==="
$vappAccess = $vapp.ExtensionData.GetControlAccess()
$vappAccess.IsSharedToEveryone = $true
$vappAccess.EveryoneAccessLevel = "FullControl"
$vapp.ExtensionData.ControlAccess($vappAccess)

write-host "===set vapp stop action==="
$vappStartupSection = $vapp.ExtensionData.GetStartupSection()
$vmShutdown = $vappStartupSection.Item[0]
$vmShutdown.StopAction = "guestShutdown"
$vappStartupSection.updateserverdata()

write-host "===set vm customization==="
$vm = get-civm -vapp $vappName
$vmCustomization = $vm.ExtensionData.GetGuestCustomizationSection()
$vmCustomization.Enabled = $true
$vmCustomization.ChangeSid = $true
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
# added by srozanc:
$vmCustomization.any = $null
$vmCustomization.updateserverdata()

write-host "===set vm name==="
$vm.extensiondata.name = $vappName
$vm.extensiondata.updateserverdata()

write-host "===set vm network=="
$vmNetworkconnectionsection = $vm.ExtensionData.GetNetworkConnectionSection()
$vmNetworkconnectionsection.PrimaryNetworkConnectionIndex = 0
$vmNetworkconnectionsection.NetworkConnection[0].Network = $orgVdcNetworkName
$vmNetworkconnectionsection.NetworkConnection[0].NeedsCustomization = $true
$vmNetworkconnectionsection.NetworkConnection[0].IsConnected = $true
$vmNetworkconnectionsection.NetworkConnection[0].IpAddress = $vappIp
$vmNetworkconnectionsection.NetworkConnection[0].IpAddressAllocationMode = "MANUAL"
$vmNetworkconnectionsection.updateServerData()

write-host "===set vm cpu/mem/disk==="
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
$vmHardware.updateserverdata()

write-host "===start vapp==="
Start-CIvApp $vapp -confirm:$false

Disconnect-CIServer -Server $ciServer  -Confirm:$false

}
Catch
{
    $ErrorMessage = $_.Exception.Message
    write-host "ERROR: $($ErrorMessage)"
    Break
}

Stop-Transcript
### END
