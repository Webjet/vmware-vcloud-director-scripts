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

#Get VappNetwork ans Set Network Adapter
Try {
    Write-Host "Setting Network Adapter"
    Get-CIVM -Name $vmname | Get-CINetworkAdapter | Set-CINetworkAdapter -VAppNetwork $vappnetwork -IPAddressAllocationMode Pool -Connected $true
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}