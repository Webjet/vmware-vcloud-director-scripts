$d = Get-Date
Write-Host "Starting $($env:sleepSeconds) seconds sleep at $($d.ToLongTimeString())"
Start-Sleep $env:sleepSeconds