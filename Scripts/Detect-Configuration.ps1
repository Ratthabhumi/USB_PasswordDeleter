function Get-LenovoFirmwareConfig {
    try {
        $biosSettings = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_BiosSetting -ErrorAction Stop
        
        $config = [PSCustomObject]@{
            BootOrder = "Unknown"
            FirmwareAuth = "Unknown"
            SecureBoot = "Unknown"
            PasswordState = "Unknown"
            PowerOnPassword = "Unknown"
            HardDiskPassword = "Unknown"
        }

        foreach ($setting in $biosSettings) {
            if ($setting.CurrentSetting -match "^BootOrder,") {
                $config.BootOrder = $setting.CurrentSetting -replace "^BootOrder," , ""
            }
            if ($setting.CurrentSetting -match "^SupervisorPassword,") {
                $config.FirmwareAuth = $setting.CurrentSetting -replace "^SupervisorPassword," , ""
            }
            if ($setting.CurrentSetting -match "^SecureBoot,") {
                $config.SecureBoot = $setting.CurrentSetting -replace "^SecureBoot," , ""
            }
            if ($setting.CurrentSetting -match "^PasswordState,") {
                $config.PasswordState = $setting.CurrentSetting -replace "^PasswordState," , ""
            }
            if ($setting.CurrentSetting -match "^PowerOnPassword,") {
                $config.PowerOnPassword = $setting.CurrentSetting -replace "^PowerOnPassword," , ""
            }
            if ($setting.CurrentSetting -match "^HardDisk1Password,") {
                $config.HardDiskPassword = $setting.CurrentSetting -replace "^HardDisk1Password," , ""
            }
            if ($setting.CurrentSetting -match "^HardDisk2Password,") {
                $val = $setting.CurrentSetting -replace "^HardDisk2Password," , ""
                if ($config.HardDiskPassword -eq "Unknown" -or $config.HardDiskPassword -eq "") {
                    $config.HardDiskPassword = $val
                }
            }
        }
        return $config
    } catch {
        Write-Warning "Failed to query Lenovo WMI namespace. Ensure you are running on supported Lenovo hardware with WinPE-WMI."
        return $null
    }
}
