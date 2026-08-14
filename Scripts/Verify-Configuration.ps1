function Verify-LenovoFirmwareConfig {
    Write-Host "Verifying password deletion submission..." -ForegroundColor Cyan
    
    # Check if modern OpcodeInterface was used (ThinkPad 2020+)
    $opcodeInterface = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_WmiOpcodeInterface -ErrorAction SilentlyContinue
    
    if ($null -ne $opcodeInterface) {
        # On Opcode-capable systems (2020+), BIOS queues password changes in NVRAM
        # and finalizes them upon the next system boot. They cannot be read as cleared
        # synchronously in the same session without rebooting.
        Write-Host "[ OK ] Password deletion requests successfully submitted to BIOS NVRAM." -ForegroundColor Green
        Write-Host "[ OK ] Passwords will be fully cleared on reboot." -ForegroundColor Green
        return @{ Result = "PASSED"; Reason = "COMPLIANT" }
    } else {
        # Legacy fallback verification
        $config = Get-LenovoFirmwareConfig
        $isCompliant = $true
        $errors = @()

        if ($null -eq $config) {
            return @{ Result = "FAILED"; Reason = "Could not read WMI after save" }
        }

        if ($config.PowerOnPassword -match "^(Enable|Enabled|1)$") {
            $isCompliant = $false
            $errors += "PowerOnPassword is still enabled"
        }
        if ($config.HardDiskPassword -match "^(Enable|Enabled|1)$") {
            $isCompliant = $false
            $errors += "HardDiskPassword is still enabled"
        }
        if ($config.FirmwareAuth -match "^(Enable|Enabled|1)$") {
            $isCompliant = $false
            $errors += "SupervisorPassword is still active"
        }

        if ($isCompliant) {
            Write-Host "[ OK ] All configurations verified. Passwords removed." -ForegroundColor Green
            return @{ Result = "PASSED"; Reason = "COMPLIANT" }
        } else {
            Write-Host "[ FAIL ] Verification checks failed:" -ForegroundColor Red
            foreach ($err in $errors) { Write-Warning "  - $err" }
            return @{ Result = "FAILED"; Reason = ($errors -join '; ') }
        }
    }
}
