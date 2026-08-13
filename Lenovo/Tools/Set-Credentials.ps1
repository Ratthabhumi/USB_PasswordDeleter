param(
    [Parameter(Mandatory=$false)]
    [string]$TargetFolder = ""
)

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "     LENOVO CREDENTIAL GENERATOR (AES-256 ENCRYPTED)    " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This tool will encrypt your authorization passwords for"
Write-Host "automatic BIOS, Power-On, and Hard Disk password deletion."
Write-Host ""

# Resolve absolute path to the project's Config directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if ([string]::IsNullOrWhiteSpace($TargetFolder)) {
    $projectRoot = Resolve-Path (Join-Path $scriptDir "..\..")
    $targetDir = Join-Path $projectRoot "Config"
} else {
    $targetDir = $TargetFolder
}

# Auto-create Config folder if it doesn't exist
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

# Static AES-256 key (Matches Apply-Configuration.ps1 in WinPE)
[byte[]]$aesKey = @(
    14, 211, 88, 142, 63, 102, 199, 45, 
    21, 66, 178, 201, 105, 91, 74, 188, 
    121, 33, 99, 145, 255, 34, 11, 77, 
    111, 222, 11, 9, 87, 44, 12, 10
)

try {
    # 1. Supervisor Password (SVP)
    Write-Host "[1/2] Supervisor Password (SVP / BIOS Master Password):" -ForegroundColor Yellow
    $svpSecure = Read-Host "Enter Current Supervisor Password" -AsSecureString
    $svpPath = Join-Path $targetDir "supervisor.txt"
    $svpSecure | ConvertFrom-SecureString -Key $aesKey | Out-File $svpPath -Force
    Write-Host "  [OK] Encrypted & saved -> Config\supervisor.txt" -ForegroundColor Green
    Write-Host ""

    # 2. Power-On & Hard Disk Password (POP / HDP)
    Write-Host "[2/2] Power-On & Hard Disk Password (Shared Password):" -ForegroundColor Yellow
    $popHddSecure = Read-Host "Enter Current Power-On / HDD Password" -AsSecureString
    $popHddPath = Join-Path $targetDir "pop_hdd.txt"
    $popHddSecure | ConvertFrom-SecureString -Key $aesKey | Out-File $popHddPath -Force
    Write-Host "  [OK] Encrypted & saved -> Config\pop_hdd.txt" -ForegroundColor Green
    Write-Host ""

    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "[ SUCCESS ] Both credentials encrypted successfully!" -ForegroundColor Green
    Write-Host "These files will be baked into the WinPE Boot USB." -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Cyan
} catch {
    Write-Host ""
    Write-Host "[ ERROR ] Failed to save credentials: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press Enter to exit..."
[void][System.Console]::ReadLine()
