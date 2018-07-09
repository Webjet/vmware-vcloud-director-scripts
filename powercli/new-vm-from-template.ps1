$ciServer = ### 'vcloud.macquarieview.com'
$apiusername = ### ''
$apipassword = ###''
$orgName = ### 'Webjet_Marketing_Pty_Ltd_42809_SVC'
$vmname = ### 'VM Name'

#Connecting to the CI Server
Try {
    #Connect-CIServer -Server "vcloud.macquarieview.com"  -User "devadmin"  -Password "P@ssw0rd" -Org "Webjet_Marketing_Pty_Ltd_42809_SVC"
    Connect-CIServer -Server $ciServer -User $apiusername -Password $apipassword -Org $orgName | Out-Null
} Catch {
	Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
} Finally {
	Write-Output "Logged into $($ciServer)"
}

#Get VDC Name:
Try {
	write-host "Getting OrgVdc name from $($orgName)"
    $orgVdc = Get-orgVdc -Org $orgName
    #$orgVdc = 'M2SVC20637001'
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}

#Get Vapp
Try {
    write-host "Getting Vapp"    
    $vappname =  Get-CIVApp -OrgVdc $orgVdc -Owner $apiusername
    #WJ-DEV-DC01 OR WJ-DEV-NODE01
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}

#Get VM Template
Try {
    $catalog = Get-Catalog -Org $orgName
    #Customer_42809_SVC_Catalog OR p8000_catalog
    Write-host "Getting VM template"
    $vmtemplate = Get-CIVMTemplate -Catalog $catalog[0]
    #W2012R2STDPUBLIC (4-core 8GB RAM)
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}

#Get Vapp Network
Try {
    Write-Host "Getting Vapp Network"
    $vappnetwork = Get-CIVApp -Name $vappname[1] | Get-CIVAppNetwork 
    #V2777-DEV1-M2VLN20637001 
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}

#Create VM from Template
Try {
    Write-Output "Creating new VM $($vmname)"
    New-CIVM -VApp $vappname[1] -VMTemplate $vmtemplate[0] -Name $vmname -ComputerName $vmname
    #New-CIVM -VApp "WJ-DEV-NODE02" -VMTemplate "WJ-DEV-NODE02" -Name "WEBJET-TEST-VM01" -ComputerName "WJ-TEST-VM01"
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}

#Get VappNetwork ans Set Network Adapter
Try {
    Write-Host "Setting Network Adapter"
    Get-CIVM -Name $vmname | Get-CINetworkAdapter | Set-CINetworkAdapter -VAppNetwork $vappnetwork -IPAddressAllocationMode Pool -Connected $true
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}

#Check VM and then start
Try {
    Write-Host "Checking if VM created then start it"
    Get-CIVM -Name $vmname | Start-CIVM
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}