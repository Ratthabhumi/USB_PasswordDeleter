function Set-InternalBootPriority {
    param(
        [Parameter(Mandatory=$false)]
        [string]$SupervisorPassword = ""
    )

    $config = Get-LenovoFirmwareConfig
    
    $password = ""
    if ($null -ne $config -and $config.FirmwareAuth -match "^(Enable|Enabled|1)$") {
        $password = if (-not [string]::IsNullOrEmpty($SupervisorPassword)) {
            $SupervisorPassword
        } else {
            Get-SecureCredential -CredentialName "supervisor"
        }
    }

    Write-Host "Restoring normal internal-drive boot priority (HDD0)..." -ForegroundColor Cyan
    try {
        $setWmi = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_SetBiosSetting
        $saveWmi = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_SaveBiosSettings

        # Safely reorder the existing boot order to prioritize internal drives
        $currentSetting = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_BiosSetting -ErrorAction Stop | Where-Object CurrentSetting -match "^BootOrder,"
        $currentOrderStr = $currentSetting.CurrentSetting -replace "^BootOrder,", ""
        
        $devices = $currentOrderStr -split ":"
        $internalDrives = $devices | Where-Object { $_ -match "^(NVMe0|HDD0)$" }
        $otherDrives = $devices | Where-Object { $_ -notmatch "^(NVMe0|HDD0)$" }
        
        $newBootOrder = ($internalDrives + $otherDrives) -join ":"
        
        $cmd = if (-not [string]::IsNullOrEmpty($password)) {
            "BootOrder,$newBootOrder,$password,ascii,us"
        } else {
            "BootOrder,$newBootOrder,,ascii,us"
        }

        Invoke-CimMethod -InputObject $setWmi -MethodName SetBiosSetting -Arguments @{Parameter=$cmd} | Out-Null
        
        # Save Boot Order changes
        $saveParam = if (-not [string]::IsNullOrEmpty($password)) { "$password,ascii,us" } else { ",ascii,us" }
        Invoke-CimMethod -InputObject $saveWmi -MethodName SaveBiosSettings -Arguments @{Parameter=$saveParam} | Out-Null
        
        Write-Host "[ OK ] Boot priority restored to internal drive." -ForegroundColor Green
        Remove-Variable -Name password -ErrorAction SilentlyContinue
        return $true
    } catch {
        Write-Warning "Failed to modify BootOrder: $($_.Exception.Message)"
        Remove-Variable -Name password -ErrorAction SilentlyContinue
        return $false
    }
}
