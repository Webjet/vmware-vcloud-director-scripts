### clone_vapp v1
###.\clone_vapp_v1.ps1 -ciServer "vcloud.macquarieview.com" -orgVdc "M2SVC20637001" -orgname "Webjet_Marketing_Pty_Ltd_42809_SVC" -apiusername "devadmin" -apipassword "P@ssw0rd" -vappNameOrig "WJ-DEV-NODE01" -vappNameNew "WJ-DEV-NODE03" -orgVdcNetworkName "V2777-DEV1-M2VLN20637001" -vappIp "172.28.85.36"
###

Param(
    [parameter(Mandatory=$true)]
    $ciServer,
    [parameter(Mandatory=$true)]
    $vappNameOrig,
	[parameter(Mandatory=$true)]
    $vappNameNew,
    [parameter(Mandatory=$true)]
    $orgVdc,
	[parameter(Mandatory=$true)]
    $orgVdcNetworkName, 	# MUST have DNS server setting if $joinDomain = $true
    [parameter(Mandatory=$true)]
    $vappIp, 
    [parameter(Mandatory=$true)]
    $orgname,
    [parameter(Mandatory=$true)]
    $apiusername,
    [parameter(Mandatory=$true)]
    $apipassword
)

$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'
try{
	stop-transcript | out-null
}
Catch [System.InvalidOperationException]{}
Start-Transcript .\CloneVApp-$vappname.txt -append -noclobber

try {
Add-PSSnapin VMware.VimAutomation.Cloud -ErrorAction SilentlyContinue
[VMware.VimAutomation.Cloud.Views.CloudClient]::ApiVersionRestriction.ForceCompatibility("5.1")
# clear text password below is for lab/demo purpose only. recommend hashing credential in production setup
Connect-CIServer -Server $ciServer -User $apiusername -Password $apipassword -Org $orgname 

##### PS C:\windows\system32> Get-CIVAppNetwork -Vapp $targetvapp | Remove-CIVAppNetwork

write-host "===Get VDC==="
$orgVdc = get-orgvdc $orgVdc

write-host "===Clone VAPP==="
New-CIVApp -Name $vappNameNew -VApp $vappNameOrig

$targetvapp = Get-CIVApp -OrgVdc $orgVdc -Name $vappNameNew

write-host "===Discard our suspended state==="
Set-CIVApp -VApp $targetvapp -DiscardSuspendedState -ErrorAction Stop

write-host "===Delete our old network==="
Get-CIVAppNetwork -Vapp $targetvapp | Remove-CIVAppNetwork -Confirm:$False -ErrorAction Stop

write-host "===set vapp network==="
$vappnetwork = new-object vmware.vimautomation.cloud.views.vappnetworkconfiguration
$vappnetwork.NetworkName = $orgVdcNetworkName
$vappnetwork.configuration = new-object vmware.vimautomation.cloud.views.networkconfiguration
$vappnetwork.configuration.fencemode = "bridged"
$vappnetwork.Configuration.ParentNetwork = New-Object vmware.vimautomation.cloud.views.reference
$vappnetwork.Configuration.ParentNetwork.Href = ($orgVdc.ExtensionData.AvailableNetworks.Network | where {$_.name -eq $orgVdcNetworkName}).href
$networkConfigSection = $targetvapp.ExtensionData.GetNetworkConfigSection()
$networkConfigSection.networkconfig += $vappnetwork
$networkConfigSection.updateserverdata()

write-host "===set vm customization==="
$vm = get-civm -vapp $targetvapp
$vmCustomization = $vm.ExtensionData.GetGuestCustomizationSection()
$vmCustomization.Enabled = $true
$vmCustomization.ChangeSid = $true
$vmCustomization.JoinDomainEnabled = $false
$vmCustomization.UseOrgSettings = $false
#if ($joinDomain) 
#{
#	$vmCustomization.DomainName = $joinDomainName
#	$vmCustomization.DomainUserName = $joinDomainUserName
#	$vmCustomization.DomainUserPassword = $joinDomainUserPassword
#	$vmCustomization.MachineObjectOU = $joinMachineObjectOU
#}
$vmCustomization.AdminPasswordEnabled = $true
$vmCustomization.AdminPasswordAuto = $true
$vmCustomization.CustomizationScript  = $customizationScript
$vmCustomization.ComputerName = $vappNameNew
# added by srozanc:
$vmCustomization.any = $null
$vmCustomization.updateserverdata()

write-host "===set vm name==="
$vm.extensiondata.name = $vappNameNew
$vm.extensiondata.updateserverdata()

write-host "===set vm network=="
$vmNetworkconnectionsection = $vm.ExtensionData.GetNetworkConnectionSection()
$vmNetworkconnectionsection.PrimaryNetworkConnectionIndex = 0
$vmNetworkconnectionsection.NetworkConnection[0].Network = $orgVdcNetworkName
$vmNetworkconnectionsection.NetworkConnection[0].NeedsCustomization = $true
$vmNetworkconnectionsection.NetworkConnection[0].IsConnected = $true
$vmNetworkconnectionsection.NetworkConnection[0].IpAddress = $vappIp
$vmNetworkconnectionsection.NetworkConnection[0].IpAddressAllocationMode = "MANUAL"
$vmNetworkconnectionsection.NetworkConnection[0].MACAddress = ""
$vmNetworkconnectionsection.updateServerData()

$vm.ExtensionData.NeedsCustomization = $true
$vm.extensiondata.updateserverdata()

Start-CIvApp $targetvapp -confirm:$false

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