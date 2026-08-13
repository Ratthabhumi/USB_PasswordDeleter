function Get-SecureCredential {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("supervisor", "pop_hdd")]
        [string]$CredentialName
    )

    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
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
    $svpPassword = Get-SecureCredential -CredentialName "supervisor"
    $popHddPassword = Get-SecureCredential -CredentialName "pop_hdd"

    if ([string]::IsNullOrEmpty($svpPassword) -and [string]::IsNullOrEmpty($popHddPassword)) {
        Write-Error "Cannot proceed: No valid credentials found in Config folder."
        return $false
    }

    Write-Host "Applying authorized company BIOS configurations..." -ForegroundColor Cyan
    $success = $true

    try {
        $setWmi = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_SetBiosSetting
        $saveWmi = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_SaveBiosSettings
        $setPwdWmi = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_SetBiosPassword -ErrorAction SilentlyContinue

        # ----------------------------------------------------
        # 1. Apply Corporate BIOS Settings using Supervisor Password
        # ----------------------------------------------------
        Write-Host "  -> Configuring Secure Boot (Disable)..."
        $cmdSb = "SecureBoot,Disable,$svpPassword,ascii,us"
        Invoke-CimMethod -InputObject $setWmi -MethodName SetBiosSetting -Arguments @{Parameter=$cmdSb} | Out-Null

        # ----------------------------------------------------
        # 2. Clear Power-On Password (POP)
        # ----------------------------------------------------
        Write-Host "  -> Clearing Power-On Password..."
        if (-not [string]::IsNullOrEmpty($popHddPassword) -and $null -ne $setPwdWmi) {
            $cmdPopPwd = "pop,$popHddPassword,,,ascii,us"
            $res = Invoke-CimMethod -InputObject $setPwdWmi -MethodName SetBiosPassword -Arguments @{Parameter=$cmdPopPwd}
            Write-Host "     Result (SetBiosPassword pop): $($res.return)"
        }
        # Fallback/Secondary attempt using Supervisor password to disable POP
        if (-not [string]::IsNullOrEmpty($svpPassword)) {
            $cmdPopSetting = "PowerOnPassword,Disable,$svpPassword,ascii,us"
            Invoke-CimMethod -InputObject $setWmi -MethodName SetBiosSetting -Arguments @{Parameter=$cmdPopSetting} | Out-Null
        }

        # ----------------------------------------------------
        # 3. Clear Hard Disk / SSD Password (HDP)
        # ----------------------------------------------------
        Write-Host "  -> Clearing Hard Disk / NVMe Password..."
        if (-not [string]::IsNullOrEmpty($popHddPassword) -and $null -ne $setPwdWmi) {
            # Try user HDP
            $cmdHdp = "hdp,$popHddPassword,,,ascii,us"
            $resHdp = Invoke-CimMethod -InputObject $setPwdWmi -MethodName SetBiosPassword -Arguments @{Parameter=$cmdHdp}
            Write-Host "     Result (SetBiosPassword hdp): $($resHdp.return)"

            # Try HDP slot 1 (NVMe)
            $cmdHdp1 = "hdp1,$popHddPassword,,,ascii,us"
            $resHdp1 = Invoke-CimMethod -InputObject $setPwdWmi -MethodName SetBiosPassword -Arguments @{Parameter=$cmdHdp1}
            Write-Host "     Result (SetBiosPassword hdp1): $($resHdp1.return)"

            # Try Master HDP (MHP) if applicable
            $cmdMhp = "mhp,$popHddPassword,,,ascii,us"
            $resMhp = Invoke-CimMethod -InputObject $setPwdWmi -MethodName SetBiosPassword -Arguments @{Parameter=$cmdMhp}
            Write-Host "     Result (SetBiosPassword mhp): $($resMhp.return)"
        }

        # ----------------------------------------------------
        # 4. Save Applied Settings before resetting Supervisor Password
        # ----------------------------------------------------
        Write-Host "  -> Committing BIOS setting changes..."
        Invoke-CimMethod -InputObject $saveWmi -MethodName SaveBiosSettings -Arguments @{Parameter="$svpPassword,ascii,us"} | Out-Null

        # ----------------------------------------------------
        # 5. Clear Supervisor Password (PAP)
        # ----------------------------------------------------
        Write-Host "  -> Clearing Supervisor / Master BIOS Password..."
        if (-not [string]::IsNullOrEmpty($svpPassword) -and $null -ne $setPwdWmi) {
            $cmdPap = "pap,$svpPassword,,,ascii,us"
            $resPap = Invoke-CimMethod -InputObject $setPwdWmi -MethodName SetBiosPassword -Arguments @{Parameter=$cmdPap}
            Write-Host "     Result (SetBiosPassword pap): $($resPap.return)"
        }

        # Final save
        Invoke-CimMethod -InputObject $saveWmi -MethodName SaveBiosSettings -Arguments @{Parameter=",ascii,us"} -ErrorAction SilentlyContinue | Out-Null
        
        Write-Host "[ OK ] Configuration and password deletion routine finished." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to apply BIOS settings: $($_.Exception.Message)"
        $success = $false
    }

    # Security: Wipe plain text passwords from RAM
    Remove-Variable -Name svpPassword -ErrorAction SilentlyContinue
    Remove-Variable -Name popHddPassword -ErrorAction SilentlyContinue
    
    return $success
}
