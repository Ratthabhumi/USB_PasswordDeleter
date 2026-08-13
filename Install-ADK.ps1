$ErrorActionPreference = 'Stop'

# ตรวจสอบสิทธิ์ Administrator และขอสิทธิ์อัตโนมัติหากยังไม่มี
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Clear-Host
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  WINDOWS ADK & WINPE AUTO INSTALLER" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

try {
    Write-Host "[1/4] Downloading Windows ADK Setup..."
    $adkSetup = "$env:TEMP\adksetup.exe"
    Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2196127" -OutFile $adkSetup
    
    Write-Host "[2/4] Installing Windows ADK (This may take 5-10 minutes)..." -ForegroundColor Yellow
    # ติดตั้งแบบเงียบ (Quiet) โดยลงเฉพาะ Deployment Tools ที่จำเป็น
    Start-Process -FilePath $adkSetup -ArgumentList "/quiet /norestart /features OptionId.DeploymentTools" -Wait
    
    Write-Host "[3/4] Downloading Windows PE Add-on..."
    $peSetup = "$env:TEMP\adkwinpesetup.exe"
    Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2196128" -OutFile $peSetup
    
    Write-Host "[4/4] Installing Windows PE Add-on (This may take 5-10 minutes)..." -ForegroundColor Yellow
    Start-Process -FilePath $peSetup -ArgumentList "/quiet /norestart /features OptionId.WindowsPreinstallationEnvironment" -Wait
    
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host " SUCCESS! Windows ADK and WinPE are installed." -ForegroundColor Green
    Write-Host " You can now run setup.bat to build the USB." -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    
    # Clean up
    Remove-Item $adkSetup -ErrorAction SilentlyContinue
    Remove-Item $peSetup -ErrorAction SilentlyContinue
    
} catch {
    Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
