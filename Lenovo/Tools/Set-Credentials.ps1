param(
    [Parameter(Mandatory=$false)]
    [string]$TargetFolder = "..\Config"
)

Write-Host "================================================"
Write-Host " LENOVO CREDENTIAL GENERATOR (AES-256)"
Write-Host "================================================"

# This is a static AES key for decryption inside WinPE.
# In a real environment, you can change these 32 bytes to your own random numbers.
[byte[]]$aesKey = @(
    14, 211, 88, 142, 63, 102, 199, 45, 
    21, 66, 178, 201, 105, 91, 74, 188, 
    121, 33, 99, 145, 255, 34, 11, 77, 
    111, 222, 11, 9, 87, 44, 12, 10
)

$plainPassword = Read-Host "Enter the authorized Supervisor Password" -AsSecureString

$encryptedPath = Join-Path $TargetFolder "supervisor.txt"

$plainPassword | ConvertFrom-SecureString -Key $aesKey | Out-File $encryptedPath -Force

Write-Host "[ OK ] Password encrypted and saved to: $encryptedPath" -ForegroundColor Green
Write-Host "This file must be placed in the Config folder of your deployment USB/WIM." -ForegroundColor Yellow
