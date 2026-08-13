function Verify-LenovoFirmwareConfig {
    Write-Host "Verifying configuration..."
    
    # We must fetch the config again to ensure changes were committed
    $config = Get-LenovoFirmwareConfig
    
    $isCompliant = $true
    $errors = @()

    if ($null -eq $config) {
        return @{ Result = "FAILED"; Reason = "Could not read WMI after save" }
    }

    # Verify Secure Boot (or other target settings)
    if ($config.SecureBoot -ne "Disable") {
        $isCompliant = $false
        $errors += "SecureBoot is $($config.SecureBoot) instead of Disable"
    }

    # Verify Power On Password is cleared
    if ($config.PowerOnPassword -notmatch "(Disable|Unknown)") {
        $isCompliant = $false
        $errors += "PowerOnPassword is still enabled: $($config.PowerOnPassword)"
    }

    # Verify Boot Order starts with HDD0
    if ($config.BootOrder -notmatch "^HDD0") {
        $isCompliant = $false
        $errors += "BootOrder does not prioritize internal drive (Current: $($config.BootOrder))"
    }

    if ($isCompliant) {
        Write-Host "[ OK ] Configuration successfully verified." -ForegroundColor Green
        return @{ Result = "PASSED"; Reason = "COMPLIANT" }
    } else {
        Write-Host "[FAIL] Verification errors found." -ForegroundColor Red
        foreach ($err in $errors) { Write-Warning $err }
        return @{ Result = "FAILED"; Reason = ($errors -join '; ') }
    }
}
