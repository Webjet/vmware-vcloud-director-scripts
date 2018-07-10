#Delete vapp
Remove-CiVapp <vapp_name>

#Disconnect from ciserver
Disconnect-CIServer -Server $ciServer -Confirm:$false

#Get internal IP
Get-CINetworkAdapter -VM <vm-name>