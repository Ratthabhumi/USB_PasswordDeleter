function Get-SecureCredential {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("supervisor", "pop_hdd")]
        [string]$CredentialName
    )

    $scriptPath = $PSScriptRoot
    $fileName = if ($CredentialName -eq "supervisor") { "supervisor.txt" } else { "pop_hdd.txt" }
    $configPath = Join-Path $scriptPath "..\Config\$fileName"

    if (-not (Test-Path $configPath)) {
        Write-Warning "Credential file not found at $configPath"
        return $null
    }

    # Must match the key used in Set-Credentials.ps1
    [byte[]]$aesKey = @(
        14, 211, 88, 142, 63, 102, 199, 45, 
        21, 66, 178, 201, 105, 91, 74, 188, 
        121, 33, 99, 145, 255, 34, 11, 77, 
        111, 222, 11, 9, 87, 44, 12, 10
    )

    try {
        $encryptedStr = Get-Content $configPath -Raw
        if ([string]::IsNullOrWhiteSpace($encryptedStr)) {
            return $null
        }
        $secureString = $encryptedStr.Trim() | ConvertTo-SecureString -Key $aesKey
        
        # Convert SecureString back to plain text strictly in RAM for WMI API calls
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
        $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        
        return $plain
    } catch {
        Write-Warning "Failed to decrypt $CredentialName password: $($_.Exception.Message)"
        return $null
    }
}

function Set-LenovoFirmwareConfig {
    param($Config)
    $svpPassword = Get-SecureCredential -CredentialName "supervisor"
    $popHddPassword = Get-SecureCredential -CredentialName "pop_hdd"

    if ([string]::IsNullOrEmpty($svpPassword) -and [string]::IsNullOrEmpty($popHddPassword)) {
        Write-Error "Cannot proceed: No valid credentials found in Config folder."
        return $false
    }

    # Only use Supervisor Password if it is actually enabled in BIOS
    if ($null -ne $Config -and $Config.FirmwareAuth -notmatch "^(Enable|Enabled|1)$") {
        Write-Host "  [INFO] Supervisor Password is not active on this machine. Proceeding without it."
        $svpPassword = ""
    }

    Write-Host "Applying authorized company BIOS configurations..." -ForegroundColor Cyan
    $success = $true

    try {
        $setWmi = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_SetBiosSetting
        $saveWmi = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_SaveBiosSettings
        $setPwdWmi = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_SetBiosPassword -ErrorAction SilentlyContinue

        # ----------------------------------------------------
        # 1. (REMOVED) SecureBoot and BootOrder changes are intentionally skipped.
        # Lenovo WMI strictly forbids mixing BIOS Settings (SecureBoot/BootOrder) 
        # with Password deletions (HDP/PAP) in the same boot cycle, which causes 
        # the 0191 Invalid remote change error. We only focus on passwords.
        # ----------------------------------------------------

        # ----------------------------------------------------
        # 3. Clear Power-On Password (POP)
        # ----------------------------------------------------
        Write-Host "  -> Clearing Power-On Password..."
        if (-not [string]::IsNullOrEmpty($popHddPassword) -and $null -ne $setPwdWmi) {
            $cmdPopPwd = "pop,$popHddPassword,,ascii,us"
            $res = Invoke-CimMethod -InputObject $setPwdWmi -MethodName SetBiosPassword -Arguments @{Parameter=$cmdPopPwd}
            Write-Host "     Result (SetBiosPassword pop): $($res.return)"
        }
        # Fallback using Supervisor Password
        if (-not [string]::IsNullOrEmpty($svpPassword)) {
            $cmdPopSetting = "PowerOnPassword,Disable,$svpPassword,ascii,us"
            Invoke-CimMethod -InputObject $setWmi -MethodName SetBiosSetting -Arguments @{Parameter=$cmdPopSetting} -ErrorAction SilentlyContinue | Out-Null
        }

        # ----------------------------------------------------
        # 4. Clear Hard Disk / SSD Password (HDP)
        # ----------------------------------------------------
        Write-Host "  -> Clearing Hard Disk / NVMe Password..."
        if (-not [string]::IsNullOrEmpty($popHddPassword) -and $null -ne $setPwdWmi) {
            # Try User HDP
            $cmdHdp = "uhdp,$popHddPassword,,ascii,us"
            $resHdp = Invoke-CimMethod -InputObject $setPwdWmi -MethodName SetBiosPassword -Arguments @{Parameter=$cmdHdp}
            Write-Host "     Result (SetBiosPassword uhdp): $($resHdp.return)"

            # Try User HDP slot 1 (NVMe)
            $cmdHdp1 = "uhdp1,$popHddPassword,,ascii,us"
            $resHdp1 = Invoke-CimMethod -InputObject $setPwdWmi -MethodName SetBiosPassword -Arguments @{Parameter=$cmdHdp1}
            Write-Host "     Result (SetBiosPassword uhdp1): $($resHdp1.return)"

            # Try User HDP slot 2
            $cmdHdp2 = "uhdp2,$popHddPassword,,ascii,us"
            $resHdp2 = Invoke-CimMethod -InputObject $setPwdWmi -MethodName SetBiosPassword -Arguments @{Parameter=$cmdHdp2}
            Write-Host "     Result (SetBiosPassword uhdp2): $($resHdp2.return)"

            # Try Master HDP (MHP)
            $cmdMhp = "mhdp,$popHddPassword,,ascii,us"
            $resMhp = Invoke-CimMethod -InputObject $setPwdWmi -MethodName SetBiosPassword -Arguments @{Parameter=$cmdMhp}
            Write-Host "     Result (SetBiosPassword mhdp): $($resMhp.return)"

            # Try Master HDP slot 1 (NVMe)
            $cmdMhp1 = "mhdp1,$popHddPassword,,ascii,us"
            $resMhp1 = Invoke-CimMethod -InputObject $setPwdWmi -MethodName SetBiosPassword -Arguments @{Parameter=$cmdMhp1}
            Write-Host "     Result (SetBiosPassword mhdp1): $($resMhp1.return)"

            # Try Master HDP slot 2
            $cmdMhp2 = "mhdp2,$popHddPassword,,ascii,us"
            $resMhp2 = Invoke-CimMethod -InputObject $setPwdWmi -MethodName SetBiosPassword -Arguments @{Parameter=$cmdMhp2}
            Write-Host "     Result (SetBiosPassword mhdp2): $($resMhp2.return)"
        }

        # ----------------------------------------------------
        # 5. Commit BIOS Setting Changes before deleting Supervisor Password
        # ----------------------------------------------------
        Write-Host "  -> Committing intermediate BIOS settings..."
        $saveParam = if (-not [string]::IsNullOrEmpty($svpPassword)) { "$svpPassword,ascii,us" } else { ",ascii,us" }
        Invoke-CimMethod -InputObject $saveWmi -MethodName SaveBiosSettings -Arguments @{Parameter=$saveParam} | Out-Null

        # ----------------------------------------------------
        # 6. Clear Supervisor Password (PAP) as the FINAL step
        # ----------------------------------------------------
        if (-not [string]::IsNullOrEmpty($svpPassword) -and $null -ne $setPwdWmi) {
            Write-Host "  -> Clearing Supervisor / Master BIOS Password..."
            $cmdPap = "pap,$svpPassword,,ascii,us"
            $resPap = Invoke-CimMethod -InputObject $setPwdWmi -MethodName SetBiosPassword -Arguments @{Parameter=$cmdPap}
            Write-Host "     Result (SetBiosPassword pap): $($resPap.return)"
        } else {
            Write-Host "  -> Skipping Supervisor Password (Already Disabled)..."
        }

        # Final save (Must use the old password to authorize the deletion!)
        Invoke-CimMethod -InputObject $saveWmi -MethodName SaveBiosSettings -Arguments @{Parameter=$saveParam} -ErrorAction SilentlyContinue | Out-Null
        
        Write-Host "[ OK ] Configuration and password deletion routine completed." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to apply BIOS settings: $($_.Exception.Message)"
        $success = $false
    }

    # Security: Wipe plain text passwords from RAM
    Remove-Variable -Name svpPassword -ErrorAction SilentlyContinue
    Remove-Variable -Name popHddPassword -ErrorAction SilentlyContinue
    
    return $success
}
