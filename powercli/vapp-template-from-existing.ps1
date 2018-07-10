$sourceVapp = '' #vapp to use as template
$newvapptemplate = '' #new vapp template

##Get available Vapp
if (!$sourceVapp) {
    Try {
        write-host "Getting Vapp for user $($apiusername) in $($orgVdc) vdc"    
        if (!$vappname) {
            $vappname = Get-CIVApp -OrgVdc $orgVdc -Owner $apiusername
            $vapp_array = $($vappname[0..9]) -join "`n"
        } 
        Write-host "Available vapps are: "`n"$vapp_array"
        #Choose vapp to use as template
        $sourceVapp = read-host "Enter Vapp to use as source: "
    } Catch {
        Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
        Exit(1)
    }
}

#Stop source Vapp
Try {
    write-host "Stopping $($sourceVapp)"
    Stop-CIVapp $sourceVapp -confirm:$false -ErrorAction Ignore | Out-Null
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
} Finally {
    write-host "$($sourceVapp) stopped successfully."
}

#Retrieve the catalog to which you want to add the new vApp template.
Try {
    write-host "Getting available catalogs"
    $catalog = Get-Catalog
    $catalog_array = $($catalog[0..9]) -join "`n"
    Write-host "Available catalogs are: "`n"$catalog_array"
    $catalog = read-host "Enter catalog to use: "
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}

if (!$newvapptemplate) {
    $newvapptemplate = read-host "Enter new vapp template name: "
}
   
Try {
    Write-Host "Creating new vapp template $($newvapptemplate) from $($sourcevapp)"
    New-CIVAppTemplate -Name $newvapptemplate -VApp $sourceVapp -OrgVdc $orgVdc -Catalog $catalog
} Catch {
    Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Exit(1)
} Finally {
    Write-host "$($newvapptemplate) created"
}

#Start source vapp
Try {
    Write-host "Starting $($sourceVapp)"
    Start-CIVApp -VApp $sourceVapp | Out-Null
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}