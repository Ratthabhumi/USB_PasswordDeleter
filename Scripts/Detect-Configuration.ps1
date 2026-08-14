function Get-LenovoFirmwareConfig {
    try {
        $config = [PSCustomObject]@{
            BootOrder         = "Unknown"
            FirmwareAuth      = "Disabled"
            SecureBoot        = "Unknown"
            PasswordState     = 0
            PowerOnPassword   = "Disabled"
            HardDiskPassword  = "Disabled"
        }

        # 1. Query Lenovo_BiosPasswordSettings for authoritative password state
        try {
            $pwdSettings = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_BiosPasswordSettings -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($null -ne $pwdSettings -and $null -ne $pwdSettings.PasswordState) {
                $state = [int]$pwdSettings.PasswordState
                $config.PasswordState = $state

                # Supervisor Password Check (States: 2, 3, 6, 7, 66, 67, 70, 71)
                if ($state -in 2, 3, 6, 7, 66, 67, 70, 71) {
                    $config.FirmwareAuth = "Enabled"
                }

                # Power-On Password Check (States: 1, 3, 5, 7, 65, 67, 69, 71)
                if ($state -in 1, 3, 5, 7, 65, 67, 69, 71) {
                    $config.PowerOnPassword = "Enabled"
                }

                # Hard Disk / NVMe Password Check (States: 4, 5, 6, 7, 68, 69, 70, 71)
                if ($state -in 4, 5, 6, 7, 68, 69, 70, 71) {
                    $config.HardDiskPassword = "Enabled"
                }
            }
        } catch {}

        # 2. Supplementary check from Lenovo_BiosSetting
        try {
            $biosSettings = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_BiosSetting -ErrorAction SilentlyContinue
            foreach ($setting in $biosSettings) {
                if ($setting.CurrentSetting -match "^BootOrder,") {
                    $config.BootOrder = $setting.CurrentSetting -replace "^BootOrder," , ""
                }
                if ($setting.CurrentSetting -match "^SecureBoot,") {
                    $config.SecureBoot = $setting.CurrentSetting -replace "^SecureBoot," , ""
                }
                if ($setting.CurrentSetting -match "^PowerOnPassword,") {
                    $val = $setting.CurrentSetting -replace "^PowerOnPassword," , ""
                    if ($val -match "^(Enable|Enabled|1)$") { $config.PowerOnPassword = "Enabled" }
                }
                if ($setting.CurrentSetting -match "^HardDisk[1-3]Password,") {
                    $val = $setting.CurrentSetting -replace "^HardDisk[1-3]Password," , ""
                    if ($val -match "^(Enable|Enabled|1|User)$") { $config.HardDiskPassword = "Enabled" }
                }
            }
        } catch {}

        return $config
    } catch {
        Write-Warning "Failed to query Lenovo WMI namespace: $($_.Exception.Message)"
        return $null
    }
}
