function Verify-LenovoFirmwareConfig {
    Write-Host "Verifying final firmware & password state..." -ForegroundColor Cyan
    
    # We must fetch the config again to ensure changes were committed in BIOS
    $config = Get-LenovoFirmwareConfig
    
    $isCompliant = $true
    $errors = @()

    if ($null -eq $config) {
        return @{ Result = "FAILED"; Reason = "Could not read WMI after save" }
    }

    # 1. Verify Secure Boot
    if ($config.SecureBoot -notin @("Disable", "Disabled", "0")) {
        $isCompliant = $false
        $errors += "SecureBoot is '$($config.SecureBoot)' instead of Disable"
    }

    # 2. Verify Power On Password is cleared
    if ($config.PowerOnPassword -match "^(Enable|Enabled|1)$") {
        $isCompliant = $false
        $errors += "PowerOnPassword is still enabled: $($config.PowerOnPassword)"
    }

    # 3. Verify Hard Disk Password is cleared
    if ($config.HardDiskPassword -match "^(Enable|Enabled|1)$") {
        $isCompliant = $false
        $errors += "HardDiskPassword is still enabled: $($config.HardDiskPassword)"
    }

    # 4. Verify Supervisor Password is cleared
    if ($config.FirmwareAuth -match "^(Enable|Enabled|1)$") {
        $isCompliant = $false
        $errors += "SupervisorPassword is still active: $($config.FirmwareAuth)"
    }

    # 5. Verify Boot Order starts with internal drive (HDD0 / NVMe)
    if ($config.BootOrder -notmatch "^HDD0") {
        $isCompliant = $false
        $errors += "BootOrder does not prioritize internal drive (Current: $($config.BootOrder))"
    }

    if ($isCompliant) {
        Write-Host "[ OK ] All configurations verified. Passwords removed." -ForegroundColor Green
        return @{ Result = "PASSED"; Reason = "COMPLIANT" }
    } else {
        Write-Host "[ FAIL ] Verification checks failed:" -ForegroundColor Red
        foreach ($err in $errors) { 
            Write-Warning "  - $err" 
        }
        return @{ Result = "FAILED"; Reason = ($errors -join '; ') }
    }
}
