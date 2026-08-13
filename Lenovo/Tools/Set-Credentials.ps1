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

function Prompt-And-Save-Password {
    param (
        [string]$StepTitle,
        [string]$TargetFileName
    )

    while ($true) {
        Write-Host "$StepTitle" -ForegroundColor Yellow
        $pwd1 = Read-Host "  1. Enter Password" -AsSecureString
        $pwd2 = Read-Host "  2. Confirm Password (Re-enter to verify)" -AsSecureString

        # Convert to plain text in RAM to verify matching
        $bstr1 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pwd1)
        $plain1 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr1)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr1)

        $bstr2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pwd2)
        $plain2 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr2)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr2)

        if ($plain1 -ne $plain2) {
            Write-Host "  [!] Error: Passwords do not match! Please try again." -ForegroundColor Red
            Write-Host ""
            continue
        }

        # Show length summary
        $len = $plain1.Length
        if ($len -eq 0) {
            Write-Host "  [!] Password is empty (No password set)." -ForegroundColor DarkGray
        } else {
            $masked = if ($len -gt 2) { $plain1.Substring(0,1) + ("*" * ($len - 2)) + $plain1.Substring($len - 1, 1) } else { "*" * $len }
            Write-Host "  [OK] Passwords match! Length: $len characters ($masked)" -ForegroundColor Green
        }

        # Optional reveal prompt so user can double-check with their own eyes
        $reveal = Read-Host "  Do you want to reveal the password to double-check? [y/N]"
        if ($reveal -match "^[yY]") {
            Write-Host "  -> Revealed password: '$plain1'" -ForegroundColor Cyan
            $confirm = Read-Host "  Save this password? [Y/n]"
            if ($confirm -match "^[nN]") {
                Write-Host "  Re-entering password..." -ForegroundColor Yellow
                Write-Host ""
                continue
            }
        }

        # Encrypt and save
        $targetPath = Join-Path $targetDir $TargetFileName
        $pwd1 | ConvertFrom-SecureString -Key $aesKey | Out-File $targetPath -Force
        Write-Host "  [OK] Encrypted and saved -> Config\$TargetFileName" -ForegroundColor Green
        Write-Host ""

        # Memory cleanup
        Remove-Variable -Name plain1, plain2 -ErrorAction SilentlyContinue
        break
    }
}

try {
    # 1. Supervisor Password
    Prompt-And-Save-Password -StepTitle "[1/2] Supervisor Password (SVP / BIOS Master Password):" -TargetFileName "supervisor.txt"

    # 2. Power-On and Hard Disk Password
    Prompt-And-Save-Password -StepTitle "[2/2] Power-On and Hard Disk Password (Shared Password):" -TargetFileName "pop_hdd.txt"

    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "[ SUCCESS ] Both credentials encrypted successfully!" -ForegroundColor Green
    Write-Host "Files saved in Config/ folder and ready for setup.bat." -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Cyan
} catch {
    Write-Host ""
    Write-Host "[ ERROR ] Failed to save credentials: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press Enter to exit..."
[void][System.Console]::ReadLine()
