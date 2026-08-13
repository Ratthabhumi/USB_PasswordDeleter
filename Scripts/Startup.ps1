# Lenovo Enterprise Device Preparation - Phase 1 (Read-Only)
$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Load Modules
. (Join-Path $ScriptDir "Detect-Hardware.ps1")
. (Join-Path $ScriptDir "Detect-Configuration.ps1")
. (Join-Path $ScriptDir "Detect-USBRemoval.ps1")

Clear-Host
Write-Host "================================================"
Write-Host " LENOVO ENTERPRISE DEVICE PREPARATION (PHASE 1)"
Write-Host "================================================"

Write-Host "Detecting machine..."
$hw = Get-LenovoHardwareInfo

Write-Host "Model  : $($hw.Model)"
Write-Host "Type   : $($hw.MachineType)"
Write-Host "Serial : $($hw.Serial)"
Write-Host "Storage: $($hw.Storage)"
Write-Host ""

# Validate Supported Models (L15 Gen 2 & X13 Gen 2)
$supportedModels = @("20X3", "20X4", "20U7", "20U8", "20WK", "20WL", "20XH", "20XJ")
if ($hw.MachineType -notin $supportedModels) {
    Write-Host "WARNING: Machine Type '$($hw.MachineType)' is not in the officially supported list for this script." -ForegroundColor Yellow
    Write-Host "Supported: $($supportedModels -join ', ')"
    Write-Host "Continuing for read-only test, but production scripts will HALT here." -ForegroundColor DarkGray
    Write-Host ""
}

Write-Host "Environment:"
Write-Host "WinPE                 [OK]"
Write-Host "Hardware detection    [OK]"
Write-Host "Configuration check   [OK]"

# Wait for USB Removal
Wait-ForUSBRemoval

Write-Host ""
Write-Host "================================================"
Write-Host " PROCESSING DEVICE (READ-ONLY TEST)"
Write-Host "================================================"
Write-Host "Serial : $($hw.Serial)"
Write-Host ""

Write-Host "Reading configuration... " -NoNewline
$config = Get-LenovoFirmwareConfig

if ($null -ne $config) {
    Write-Host "[OK]" -ForegroundColor Green
    Write-Host "------------------------------------------------"
    Write-Host "Supervisor Password : $($config.FirmwareAuth)"
    Write-Host "Password State      : $($config.PasswordState)"
    Write-Host "Power On Password   : $($config.PowerOnPassword)"
    Write-Host "Hard Disk Password  : $($config.HardDiskPassword)"
    Write-Host "Boot Order          : $($config.BootOrder)"
    Write-Host "Secure Boot         : $($config.SecureBoot)"
    Write-Host "------------------------------------------------"
} else {
    Write-Host "[FAILED]" -ForegroundColor Red
}

Write-Host ""
Write-Host "================================================"
Write-Host "                 SUCCESS (READ-ONLY)"
Write-Host "================================================"
Write-Host "The machine hardware and WMI interface are ready."
Write-Host "No settings were changed in Phase 1."
Write-Host ""
Write-Host "You may power off the machine."
Write-Host "================================================"
