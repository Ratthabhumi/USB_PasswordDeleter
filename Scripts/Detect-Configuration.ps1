function Get-LenovoFirmwareConfig {
    try {
        $biosSettings = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_BiosSetting -ErrorAction Stop
        
        $config = [PSCustomObject]@{
            BootOrder         = "Unknown"
            FirmwareAuth      = "Unknown"
            SecureBoot        = "Unknown"
            PasswordState     = "Unknown"
            PowerOnPassword   = "Unknown"
            HardDiskPassword  = "Unknown"
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
            if ($setting.CurrentSetting -match "^HardDisk[1-3]Password,") {
                $val = $setting.CurrentSetting -replace "^HardDisk[1-3]Password," , ""
                if ($val -match "^(Enable|Enabled|1|User)$") {
                    $config.HardDiskPassword = $val
                } elseif ($config.HardDiskPassword -eq "Unknown") {
                    $config.HardDiskPassword = $val
                }
            }
        }

        # Supplementary check via Lenovo_BiosPasswordSettings
        try {
            $pwdSettings = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_BiosPasswordSettings -ErrorAction SilentlyContinue
            if ($null -ne $pwdSettings -and $null -ne $pwdSettings.PasswordState) {
                if ($config.PasswordState -eq "Unknown" -or [string]::IsNullOrEmpty($config.PasswordState)) {
                    $config.PasswordState = "$($pwdSettings.PasswordState)"
                }
            }
        } catch {}

        return $config
    } catch {
        Write-Warning "Failed to query Lenovo WMI namespace. Ensure you are running on supported Lenovo hardware with WinPE-WMI."
        return $null
    }
}
