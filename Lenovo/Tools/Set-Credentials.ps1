param(
    [Parameter(Mandatory=$false)]
    [string]$TargetFolder = ""
)

Write-Host "================================================"
Write-Host " LENOVO CREDENTIAL GENERATOR (AES-256)"
Write-Host "================================================"

# Resolve absolute path to the project's Config directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if ([string]::IsNullOrWhiteSpace($TargetFolder)) {
    # If script is in Lenovo\Tools, project root is 2 levels up
    $projectRoot = Resolve-Path (Join-Path $scriptDir "..\..")
    $targetDir = Join-Path $projectRoot "Config"
} else {
    $targetDir = $TargetFolder
}

# Auto-create Config folder if it doesn't exist
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

# Static AES key (Must match Apply-Configuration.ps1)
[byte[]]$aesKey = @(
    14, 211, 88, 142, 63, 102, 199, 45, 
    21, 66, 178, 201, 105, 91, 74, 188, 
    121, 33, 99, 145, 255, 34, 11, 77, 
    111, 222, 11, 9, 87, 44, 12, 10
)

try {
    $plainPassword = Read-Host "Enter the authorized Supervisor Password" -AsSecureString

    $encryptedPath = Join-Path $targetDir "supervisor.txt"

    $plainPassword | ConvertFrom-SecureString -Key $aesKey | Out-File $encryptedPath -Force

    Write-Host ""
    Write-Host "[ OK ] Password encrypted and saved to:" -ForegroundColor Green
    Write-Host "       $encryptedPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This file will be included in the Config folder of your deployment USB/WIM." -ForegroundColor Yellow
} catch {
    Write-Host ""
    Write-Host "[ ERROR ] Failed to save credential: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press Enter to exit..."
[void][System.Console]::ReadLine()

