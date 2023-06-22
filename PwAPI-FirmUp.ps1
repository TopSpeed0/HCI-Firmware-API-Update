#Requires -Version 7.0
<#
.SYNOPSIS
This script requires PowerShell 7 or higher.

.DESCRIPTION
The script retrieves detailed information about the selected node using cURL and the provided API endpoint. The result is converted from JSON format using ConvertFrom-Json and stored in the $SelectedNode variable.

Next, the script displays the IPMI (Intelligent Platform Management Interface) information of the selected host and prompts the user to access a URL for an overview of the process. The Write-Host and pause commands are used for this purpose.

After the user confirms the start of the firmware upgrade process, the script sends a POST request to the mnode API to initiate the upgrade. The request payload is constructed using a hashtable ($json) containing various parameters such as force, maintenanceMode, controllerId, packageName, and packageVersion. The payload is converted to JSON format using ConvertTo-Json and sent using cURL.

A brief pause is added using the sleep command to allow time for the upgrade to start.

Finally, the script retrieves the update status of the firmware upgrade using a GET request to the appropriate API endpoint. The result will provide information about the ongoing upgrade process.

Overall, this part of the script demonstrates the interaction with the API to initiate a firmware upgrade on the selected node and obtain the update status.

.NOTES
Author: yitzhak Bohadana
Date: June 22, 2023
Requires: PowerShell 7 or higher

#>

# general Settings
$mnode = 'mnode-ip'
$MVIP = 'mvip-ip'
$username = 'username'
# can get also from $instalation.compute.inventory.clusters.controllerId
$controllerID = '3b4e07fe-26a6-4ba3-a27d-827a7f8f35fe'
#firmware name u can also get https://mnode/package-repository/1/packages?name=compute-firmware
$firmwareName = '2.174.0-12.8.11'

# Password
# set password
# $pswd = "*********"

# File locations
$keyFile = "c:\Scripts\HCI\cert_key.key"
$pswdFile = "c:\Scripts\HCI\pswd_file_enc.txt"

# Step 1 - Create key file
# $key = New-Object Byte[] 32
# [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($key)
# $key | Out-File -FilePath $keyFile

# Step 2 - Create password file with key encryption
# $secPswd = $pswd | ConvertTo-SecureString -AsPlainText -Force
# $secPswd | ConvertFrom-SecureString -Key (Get-Content -Path $keyFile) | Set-Content -Path $pswdFile

# Step 3 - Retrieve password
$password = Get-Content -Path $pswdFile | ConvertTo-SecureString -Key (Get-Content -Path $keyFile) |  ConvertFrom-SecureString -AsPlainText
# Write-Host "this is my Password: $password"

<#
older method in ps5
# File locations
$keyFile = "c:\Scripts\HCI\cert_key.key"
$pswdFile = "c:\Scripts\HCI\pswd_file_enc.txt"

# Step 3 - Retrieve password
$encryptedPassword = Get-Content -Path $pswdFile | ConvertTo-SecureString -Key (Get-Content -Path $keyFile)
$password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($encryptedPassword))

Write-Host "This is my password: $password"
#>
# end of password

# set token
$token = curl.exe -k -X POST https://$MVIP/auth/connect/token -F client_id=mnode-client -F grant_type=password -F username=$username -F password=$password
$_token = $($token.split('"')[3])

# import instalation inventory/1/installations
$instalation = curl.exe -k -X GET "https://$mnode/inventory/1/installations" -H  "accept: application/json" -H  "Authorization: Bearer $($_token)"
$instalation  = $instalation | ConvertFrom-Json
$instalation = curl.exe -k -X GET "https://$mnode/inventory/1/installations/$($instalation.installations.id)" -H  "accept: application/json" -H  "Authorization: Bearer $($_token)"
$instalation  = $instalation | ConvertFrom-Json

# import json or $instalation = Get-Content 'E:\Downloads\response_1687338596352.json' | ConvertFrom-Json
$_nodes = $instalation.compute.inventory.nodes | ? { $_.networking.hostname -match 'thc'} | Select-Object hardwareId,{$_.networking.hostname}

# set Hardware ID
$_HardwareID = $_nodes | Out-GridView -Title "Select ESXi Hardware ID" -OutputMode Single
$HardwareID = $_HardwareID.hardwareId
$FullNodeInfo = $instalation.compute.inventory.nodes | ? { $_.hardwareId -eq $HardwareID}
# $HardwareID = '3d2da648-126b-40b3-b863-4e53bda1ad1e'


# selected node
$SelectedNode = curl.exe -k -X GET "https://$mnode/hardware/2/nodes/$HardwareID" -H  "accept: application/json" -H  "Authorization: Bearer $($_token)"
$SelectedNode = $SelectedNode | ConvertFrom-Json

# list IPMI of Selected Host 
write-host ""
write-host "Selected Host IPMI:$($SelectedNode.host) you can https://$($SelectedNode.host)/#login for overview the proccess..." -ForegroundColor Blue
pause

# run update 
write-host ""
write-host "Start firmware Upgrade on:$($FullNodeInfo.networking.hostname) to:$firmwareName ? . . ." -ForegroundColor Yellow -NoNewline
pause

$json = @{
    "config" = @{
        "force" = $false
        "maintenanceMode" = $true
    }
    "controllerId" = "$controllerID"
    "packageName" = "compute-firmware"
    "packageVersion" = "$firmwareName"
} 
curl.exe -k -X POST "https://$mnode/hardware/2/nodes/$HardwareID/upgrades" -H  "accept: application/json" -H  "Authorization: Bearer $($_token)" -H  "Content-Type: application/json" -d ($json| ConvertTo-Json)

sleep 3
# get update status
curl.exe -k -X GET "https://$mnode/hardware/2/nodes/$HardwareID/upgrades?status=inProgress" -H  "accept: application/json" -H  "Authorization: Bearer $($_token)"
