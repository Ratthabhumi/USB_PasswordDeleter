# Lenovo Enterprise Device Preparation - Phase 3 & 4 (Production)
$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Load all modules
. (Join-Path $ScriptDir "Detect-Hardware.ps1")
. (Join-Path $ScriptDir "Detect-Configuration.ps1")
. (Join-Path $ScriptDir "Detect-USBRemoval.ps1")
. (Join-Path $ScriptDir "Apply-Configuration.ps1")
. (Join-Path $ScriptDir "BootOrder.ps1")
. (Join-Path $ScriptDir "Verify-Configuration.ps1")
. (Join-Path $ScriptDir "Logging.ps1")

Clear-Host
Write-Host "================================================"
Write-Host " LENOVO ENTERPRISE DEVICE PREPARATION (PROD)"
Write-Host "================================================"

Write-Host "Detecting machine..."
$hw = Get-LenovoHardwareInfo

Write-Host "Model  : $($hw.Model)"
Write-Host "Type   : $($hw.MachineType)"
Write-Host "Serial : $($hw.Serial)"

$supportedModels = @("20X3", "20X4", "20U7", "20U8", "20WK", "20WL", "20XH", "20XJ")
if ($hw.MachineType -notin $supportedModels) {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Red
    Write-Host "            MANUAL REQUIRED" -ForegroundColor Red
    Write-Host "================================================" -ForegroundColor Red
    Write-Host "Reason: Unsupported Machine Type: $($hw.MachineType)"
    Write-AuditLog -Serial $hw.Serial -MachineType $hw.MachineType -Model $hw.Model -BIOSVersion $hw.BIOSVersion -Storage $hw.Storage -Result "MANUAL_REQUIRED" -ErrorDetail "Unsupported Machine Type"
    exit
}

Write-Host "Environment:          [OK]"

Wait-ForUSBRemoval

Write-Host ""
Write-Host "================================================"
Write-Host " PROCESSING DEVICE"
Write-Host "================================================"
Write-Host "Serial : $($hw.Serial)"

Write-Host "Reading configuration... " -NoNewline
$config = Get-LenovoFirmwareConfig
if ($null -eq $config) {
    Write-Host "[FAILED]" -ForegroundColor Red
    Write-Host "================================================"
    Write-Host "            MANUAL REQUIRED"
    Write-Host "================================================"
    Write-Host "Reason: WMI not ready or readable."
    Write-AuditLog -Serial $hw.Serial -MachineType $hw.MachineType -Model $hw.Model -BIOSVersion $hw.BIOSVersion -Storage $hw.Storage -Result "MANUAL_REQUIRED" -ErrorDetail "WMI Read Fail"
    exit
}
Write-Host "[OK]" -ForegroundColor Green

# Check if already compliant
if ($config.SecureBoot -eq "Disable" -and $config.BootOrder -match "^HDD0") {
    Write-Host "System is already compliant. No changes needed."
    Write-AuditLog -Serial $hw.Serial -MachineType $hw.MachineType -Model $hw.Model -BIOSVersion $hw.BIOSVersion -Storage $hw.Storage -Result "ALREADY_COMPLIANT" -ErrorDetail ""
} else {
    $applyResult = Set-LenovoFirmwareConfig
    
    if ($applyResult) {
        $bootResult = Set-InternalBootPriority
    } else {
        Write-Host "Configuration failed. See errors above."
        Write-AuditLog -Serial $hw.Serial -MachineType $hw.MachineType -Model $hw.Model -BIOSVersion $hw.BIOSVersion -Storage $hw.Storage -Result "MANUAL_REQUIRED" -ErrorDetail "Set-LenovoFirmwareConfig Failed"
        exit
    }
}

$verifyResult = Verify-LenovoFirmwareConfig

if ($verifyResult.Result -eq "PASSED" -or $verifyResult.Reason -eq "COMPLIANT") {
    Write-AuditLog -Serial $hw.Serial -MachineType $hw.MachineType -Model $hw.Model -BIOSVersion $hw.BIOSVersion -Storage $hw.Storage -Result "SUCCESS" -ErrorDetail ""
    Write-Host ""
    Write-Host "================================================"
    Write-Host "                 SUCCESS"
    Write-Host "================================================"
    Write-Host "Serial : $($hw.Serial)"
    Write-Host ""
    Write-Host "Firmware configuration : COMPLIANT"
    Write-Host "Storage configuration  : COMPLIANT"
    Write-Host "Boot priority          : RESTORED"
    Write-Host "Verification           : PASSED"
    Write-Host ""
    Write-Host "The machine is ready."
    Write-Host "System will shut down automatically in 5 seconds."
    Write-Host "================================================"
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
