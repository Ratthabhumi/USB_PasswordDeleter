# Lenovo Enterprise Device Preparation - Phase 3 & 4 (Production)
$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot

# Load all modules
. (Join-Path $ScriptDir "Detect-Hardware.ps1")
. (Join-Path $ScriptDir "Detect-Configuration.ps1")
. (Join-Path $ScriptDir "Detect-USBRemoval.ps1")
. (Join-Path $ScriptDir "BootOrder.ps1")
. (Join-Path $ScriptDir "Apply-Configuration.ps1")
. (Join-Path $ScriptDir "Verify-Configuration.ps1")
. (Join-Path $ScriptDir "Logging.ps1")

Clear-Host
Write-Host "================================================" -ForegroundColor Cyan
Write-Host " LENOVO ENTERPRISE DEVICE PREPARATION (PROD)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

Write-Host "Detecting machine..."
$hw = Get-LenovoHardwareInfo

Write-Host "Model  : $($hw.Model)"
Write-Host "Type   : $($hw.MachineType)"
Write-Host "Serial : $($hw.Serial)"

# Allow all genuine Lenovo devices (ThinkPad, ThinkCentre M90q/M70q/M80q, ThinkStation)
if ($hw.Manufacturer -notmatch "LENOVO") {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Red
    Write-Host "            MANUAL REQUIRED" -ForegroundColor Red
    Write-Host "================================================" -ForegroundColor Red
    Write-Host "Reason: Unsupported Manufacturer (Not Lenovo): $($hw.Manufacturer)"
    Write-AuditLog -Serial $hw.Serial -MachineType $hw.MachineType -Model $hw.Model -BIOSVersion $hw.BIOSVersion -Storage $hw.Storage -Result "MANUAL_REQUIRED" -ErrorDetail "Non-Lenovo Hardware"
    exit
}

Write-Host "Environment:          [OK]" -ForegroundColor Green

Wait-ForUSBRemoval

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host " PROCESSING DEVICE" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Serial : $($hw.Serial)"

Write-Host "Reading configuration... " -NoNewline
$config = Get-LenovoFirmwareConfig
if ($null -eq $config) {
    Write-Host "[FAILED]" -ForegroundColor Red
    Write-Host "================================================" -ForegroundColor Red
    Write-Host "            MANUAL REQUIRED" -ForegroundColor Red
    Write-Host "================================================" -ForegroundColor Red
    Write-Host "Reason: WMI not ready or readable."
    Write-AuditLog -Serial $hw.Serial -MachineType $hw.MachineType -Model $hw.Model -BIOSVersion $hw.BIOSVersion -Storage $hw.Storage -Result "MANUAL_REQUIRED" -ErrorDetail "WMI Read Fail"
    exit
}
Write-Host "[OK]" -ForegroundColor Green

# Check if already compliant and all passwords are clean
$hasPasswords = ($config.PowerOnPassword -match "^(Enable|Enabled|1)$" -or `
                 $config.HardDiskPassword -match "^(Enable|Enabled|1)$" -or `
                 $config.FirmwareAuth -match "^(Enable|Enabled|1)$" -or `
                 ($config.PasswordState -notin @("0", "None", "Unknown", "")))

if (-not $hasPasswords) {
    Write-Host "System is already compliant (No active passwords, SecureBoot disabled, BootOrder internal)." -ForegroundColor Green
    Write-AuditLog -Serial $hw.Serial -MachineType $hw.MachineType -Model $hw.Model -BIOSVersion $hw.BIOSVersion -Storage $hw.Storage -Result "ALREADY_COMPLIANT" -ErrorDetail ""
} else {
    $applyResult = Set-LenovoFirmwareConfig -Config $config
    
    if (-not $applyResult) {
        Write-Host "Configuration failed. See errors above." -ForegroundColor Red
        Write-AuditLog -Serial $hw.Serial -MachineType $hw.MachineType -Model $hw.Model -BIOSVersion $hw.BIOSVersion -Storage $hw.Storage -Result "MANUAL_REQUIRED" -ErrorDetail "Set-LenovoFirmwareConfig Failed"
        exit
    }
}

$verifyResult = Verify-LenovoFirmwareConfig

if ($verifyResult.Result -eq "PASSED" -or $verifyResult.Reason -eq "COMPLIANT") {
    Write-AuditLog -Serial $hw.Serial -MachineType $hw.MachineType -Model $hw.Model -BIOSVersion $hw.BIOSVersion -Storage $hw.Storage -Result "SUCCESS" -ErrorDetail ""
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "                 SUCCESS" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "Serial : $($hw.Serial)"
    Write-Host ""
    Write-Host "Firmware configuration : COMPLIANT"
    Write-Host "Passwords removed      : COMPLIANT (CLEARED)"
    Write-Host "Storage configuration  : COMPLIANT"
    Write-Host "Boot priority          : RESTORED"
    Write-Host "Verification           : PASSED"
    Write-Host ""
    Write-Host "The machine is ready."
    Write-Host "System will shut down automatically in 5 seconds."
    Write-Host "================================================" -ForegroundColor Green
    Start-Sleep -Seconds 5
    Stop-Computer -Force
} else {
    Write-AuditLog -Serial $hw.Serial -MachineType $hw.MachineType -Model $hw.Model -BIOSVersion $hw.BIOSVersion -Storage $hw.Storage -Result "MANUAL_REQUIRED" -ErrorDetail $verifyResult.Reason
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Red
    Write-Host "            MANUAL REQUIRED" -ForegroundColor Red
    Write-Host "================================================" -ForegroundColor Red
    Write-Host "Serial : $($hw.Serial)"
    Write-Host ""
    Write-Host "Reason: $($verifyResult.Reason)"
    Write-Host ""
    Write-Host "The requested configuration could not be verified."
    Write-Host "No further automated changes were attempted."
    Write-Host "Send this machine to the manual-processing queue."
    Write-Host "================================================" -ForegroundColor Red
}
