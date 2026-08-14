# Mock-WMI-Simulator.ps1
# This script simulates a Lenovo BIOS to test Apply-Configuration.ps1 without real hardware.

$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot

Write-Host "================================================" -ForegroundColor Cyan
Write-Host " LENOVO WMI MOCK SIMULATOR" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Load the actual script to be tested
. (Join-Path $ScriptDir "Scripts\Apply-Configuration.ps1")

# Override Get-SecureCredential to bypass AES decryption and feed fake passwords
function Get-SecureCredential {
    param([string]$CredentialName)
    if ($CredentialName -eq "supervisor") { return "FakeSVP123!" }
    if ($CredentialName -eq "pop_hdd") { return "FakeHDD123!" }
    return $null
}

# Override internal boot priority to just log it
function Set-InternalBootPriority {
    param([string]$SupervisorPassword)
    Write-Host "     [MOCK] Set-InternalBootPriority called with SVP=$SupervisorPassword" -ForegroundColor DarkGray
}

# Override Get-CimInstance to return dummy objects
function Get-CimInstance {
    param($Namespace, $ClassName, $ErrorAction)
    return @{ ClassName = $ClassName } 
}

# Override Invoke-CimMethod to simulate BIOS responses
function Invoke-CimMethod {
    param($InputObject, $MethodName, $Arguments, $ErrorAction)
    
    $payload = $Arguments.Parameter
    Write-Host "     [WMI SEND] Class: $($InputObject.ClassName) | Payload: $payload" -ForegroundColor DarkGray
    
    # -----------------------------------------------------------------
    # SIMULATE ERRORS HERE (Uncomment to test different failure modes)
    # -----------------------------------------------------------------
    
    # Simulate Error 0191 (Access Denied) when deleting Supervisor Password
    # if ($payload -match "^pap,") { return @{ return = "Access Denied" } }

    # Simulate Invalid Parameter when clearing POP
    # if ($payload -match "^pop,") { return @{ return = "Invalid Parameter" } }

    # Simulate Not Supported for MHP (Master HDD Password)
    if ($payload -match "^mhp,") { return @{ return = "Not Supported" } }
    
    # -----------------------------------------------------------------
    
    # Default success response
    return @{ return = "Success" }
}

Write-Host "`n[TEST 1] Running Set-LenovoFirmwareConfig (Happy Path)...`n" -ForegroundColor Yellow

$result = Set-LenovoFirmwareConfig

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host " MOCK SIMULATOR RESULTS" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
if ($result.Success) {
    Write-Host "Result        : SUCCESS" -ForegroundColor Green
    Write-Host "Error Message : (None)" -ForegroundColor Green
} else {
    Write-Host "Result        : FAILED" -ForegroundColor Red
    Write-Host "Error Message : $($result.ErrorMessage)" -ForegroundColor Red
}
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Try opening Mock-WMI-Simulator.ps1 and uncommenting the 'Access Denied' lines to test the Error Logger!" -ForegroundColor Magenta

Read-Host "Press Enter to exit..." | Out-Null
