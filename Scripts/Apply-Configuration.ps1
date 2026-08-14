function Get-SecureCredential {
    param(
        [Parameter(Mandatory = $true)]
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
    }
    catch {
        Write-Warning "Failed to decrypt $CredentialName password: $($_.Exception.Message)"
        return $null
    }
}

function Set-LenovoFirmwareConfig {
    $svpPassword = Get-SecureCredential -CredentialName "supervisor"
    $popHddPassword = Get-SecureCredential -CredentialName "pop_hdd"

    if ([string]::IsNullOrEmpty($svpPassword) -and [string]::IsNullOrEmpty($popHddPassword)) {
        Write-Error "Cannot proceed: No valid credentials found in Config folder."
        return @{ Success = $false; ErrorMessage = "No valid credentials found" }
    }

    Write-Host "Applying authorized company BIOS configurations..." -ForegroundColor Cyan
    $success = $true
    $errorMessages = @()

    try {
        $setWmi = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_SetBiosSetting
        $saveWmi = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_SaveBiosSettings
        $setPwdWmi = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_SetBiosPassword -ErrorAction SilentlyContinue

        # ----------------------------------------------------
        # 1. Apply Corporate BIOS Settings using Supervisor Password
        # ----------------------------------------------------
        Write-Host "  -> Configuring Secure Boot (Disable)..."
        $cmdSb = if (-not [string]::IsNullOrEmpty($svpPassword)) { "SecureBoot,Disable,$svpPassword,ascii,us" } else { "SecureBoot,Disable,,ascii,us" }
        $resSb = Invoke-CimMethod -InputObject $setWmi -MethodName SetBiosSetting -Arguments @{Parameter = $cmdSb } -ErrorAction SilentlyContinue
        if ($resSb.return -ne "Success" -and $resSb.return -ne "Not Supported") { $errorMessages += "SecureBoot: $($resSb.return)" }

        # ----------------------------------------------------
        # 2. Restore Internal Boot Priority (HDD0) BEFORE clearing SVP
        # ----------------------------------------------------
        Write-Host "  -> Restoring internal boot priority (HDD0)..."
        Set-InternalBootPriority -SupervisorPassword $svpPassword | Out-Null

        # ----------------------------------------------------
        # 3. Clear Power-On Password (POP)
        # ----------------------------------------------------
        Write-Host "  -> Clearing Power-On Password..."
        if (-not [string]::IsNullOrEmpty($popHddPassword) -and $null -ne $setPwdWmi) {
            # Provide SVP as 6th parameter if available to authorize POP deletion
            $svpAuth = if (-not [string]::IsNullOrEmpty($svpPassword)) { ",$svpPassword" } else { "" }
            $cmdPopPwd = "pop,$popHddPassword,,,ascii,us$svpAuth"
            $resPop = Invoke-CimMethod -InputObject $setPwdWmi -MethodName SetBiosPassword -Arguments @{Parameter = $cmdPopPwd }
            Write-Host "     Result (SetBiosPassword pop): $($resPop.return)"
            if ($resPop.return -ne "Success" -and $resPop.return -ne "Not Supported" -and $resPop.return -ne "Invalid Parameter") {
                $errorMessages += "Clear POP: $($resPop.return)"
            }
        }
        # Fallback using Supervisor Password via SetBiosSetting
        if (-not [string]::IsNullOrEmpty($svpPassword)) {
            $cmdPopSetting = "PowerOnPassword,Disable,$svpPassword,ascii,us"
            $resPopSetting = Invoke-CimMethod -InputObject $setWmi -MethodName SetBiosSetting -Arguments @{Parameter = $cmdPopSetting } -ErrorAction SilentlyContinue
        }

        # ----------------------------------------------------
        # 4. Clear Hard Disk / SSD Password (HDP) & M.2
        # ----------------------------------------------------
        Write-Host "  -> Clearing Hard Disk / NVMe Password..."
        
        # M.2 ThinkCentre Special Auth: Must authorize with WmiOpcodePasswordAdmin using SVP before clearing adrp1
        if (-not [string]::IsNullOrEmpty($svpPassword)) {
            $cmdWmiAdmin = "WmiOpcodePasswordAdmin,$svpPassword"
            $resAdmin = Invoke-CimMethod -InputObject $setWmi -MethodName SetBiosSetting -Arguments @{Parameter = $cmdWmiAdmin } -ErrorAction SilentlyContinue
            if ($null -ne $resAdmin -and $resAdmin.return -ne "Not Supported") {
                Write-Host "     Result (WmiOpcodePasswordAdmin): $($resAdmin.return)"
            }
        }

        if ($null -ne $setPwdWmi) {
            # Must pass SVP as the 6th parameter to authorize HDD password deletion when SVP is set
            $svpAuth = if (-not [string]::IsNullOrEmpty($svpPassword)) { ",$svpPassword" } else { "" }
            
            # Combine passwords to test for HDD: user might have used POP or SVP as the HDD password
            $passwordsToTest = @()
            if (-not [string]::IsNullOrEmpty($popHddPassword)) { $passwordsToTest += $popHddPassword }
            if (-not [string]::IsNullOrEmpty($svpPassword) -and $popHddPassword -ne $svpPassword) { $passwordsToTest += $svpPassword }

            foreach ($pwd in $passwordsToTest) {
                # Try user HDP
                $cmdHdp = "hdp,$pwd,,,ascii,us$svpAuth"
                $resHdp = Invoke-CimMethod -InputObject $setPwdWmi -MethodName SetBiosPassword -Arguments @{Parameter = $cmdHdp } -ErrorAction SilentlyContinue
                if ($resHdp.return -eq "Success") { Write-Host "     Result (hdp unlocked): Success" }

                # Try HDP slot 1 (NVMe)
                $cmdHdp1 = "hdp1,$pwd,,,ascii,us$svpAuth"
                $resHdp1 = Invoke-CimMethod -InputObject $setPwdWmi -MethodName SetBiosPassword -Arguments @{Parameter = $cmdHdp1 } -ErrorAction SilentlyContinue
                if ($resHdp1.return -eq "Success") { Write-Host "     Result (hdp1 unlocked): Success" }

                # Try Master HDP (MHP)
                $cmdMhp = "mhp,$pwd,,,ascii,us$svpAuth"
                $resMhp = Invoke-CimMethod -InputObject $setPwdWmi -MethodName SetBiosPassword -Arguments @{Parameter = $cmdMhp } -ErrorAction SilentlyContinue
                if ($resMhp.return -eq "Success") { Write-Host "     Result (mhp unlocked): Success" }

                # Try M.2 Admin (adrp1)
                $cmdAdrp1 = "adrp1,$pwd,,,ascii,us$svpAuth"
                $resAdrp1 = Invoke-CimMethod -InputObject $setPwdWmi -MethodName SetBiosPassword -Arguments @{Parameter = $cmdAdrp1 } -ErrorAction SilentlyContinue
                if ($resAdrp1.return -eq "Success") { Write-Host "     Result (adrp1 unlocked): Success" }
            }
        }

        # ----------------------------------------------------
        # 5. Commit BIOS Setting Changes before deleting Supervisor Password
        # ----------------------------------------------------
        Write-Host "  -> Committing intermediate BIOS settings..."
        $saveParam = if (-not [string]::IsNullOrEmpty($svpPassword)) { "$svpPassword,ascii,us" } else { ",ascii,us" }
        Invoke-CimMethod -InputObject $saveWmi -MethodName SaveBiosSettings -Arguments @{Parameter = $saveParam } | Out-Null

        # ----------------------------------------------------
        # 6. Clear Supervisor Password (PAP) as the FINAL step
        # ----------------------------------------------------
        Write-Host "  -> Clearing Supervisor / Master BIOS Password..."
        if (-not [string]::IsNullOrEmpty($svpPassword) -and $null -ne $setPwdWmi) {
            $cmdPap = "pap,$svpPassword,,,ascii,us"
            $resPap = Invoke-CimMethod -InputObject $setPwdWmi -MethodName SetBiosPassword -Arguments @{Parameter = $cmdPap }
            Write-Host "     Result (SetBiosPassword pap): $($resPap.return)"
            if ($resPap.return -ne "Success" -and $resPap.return -ne "Not Supported" -and $resPap.return -ne "Invalid Parameter") {
                $errorMessages += "Clear SVP: $($resPap.return)"
            }
        }

        # Final save
        $resSave = Invoke-CimMethod -InputObject $saveWmi -MethodName SaveBiosSettings -Arguments @{Parameter = ",ascii,us" } -ErrorAction SilentlyContinue
        if ($resSave.return -ne "Success") { $errorMessages += "Final Save: $($resSave.return)" }
        
        Write-Host "[ OK ] Configuration and password deletion routine completed." -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to apply BIOS settings: $($_.Exception.Message)"
        $success = $false
        $errorMessages += "Exception: $($_.Exception.Message)"
    }

    # Security: Wipe plain text passwords from RAM
    Remove-Variable -Name svpPassword -ErrorAction SilentlyContinue
    Remove-Variable -Name popHddPassword -ErrorAction SilentlyContinue
    
    $finalError = if ($errorMessages.Count -gt 0) { $errorMessages -join " | " } else { "" }
    if ($errorMessages.Count -gt 0) { $success = $false }

    return @{ Success = $success; ErrorMessage = $finalError }
}
