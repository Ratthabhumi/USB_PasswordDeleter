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

function Invoke-LenovoClearPassword {
    param(
        [Parameter(Mandatory=$true)][string]$PasswordType,
        [Parameter(Mandatory=$true)][AllowEmptyString()][string]$CurrentPassword,
        [Parameter(Mandatory=$false)][object]$OpcodeInterface = $null,
        [Parameter(Mandatory=$false)][object]$LegacyInterface = $null
    )

    if ($null -ne $OpcodeInterface) {
        # Modern OpcodeInterface path (ThinkPad 2020+)
        try {
            Invoke-CimMethod -InputObject $OpcodeInterface -MethodName WmiOpcodeInterface -Arguments @{Parameter="WmiOpcodePasswordType:$PasswordType;"} -ErrorAction Stop | Out-Null
            Invoke-CimMethod -InputObject $OpcodeInterface -MethodName WmiOpcodeInterface -Arguments @{Parameter="WmiOpcodePasswordCurrent01:$CurrentPassword;"} -ErrorAction Stop | Out-Null
            Invoke-CimMethod -InputObject $OpcodeInterface -MethodName WmiOpcodeInterface -Arguments @{Parameter="WmiOpcodePasswordNew01:;"} -ErrorAction Stop | Out-Null
            $result = Invoke-CimMethod -InputObject $OpcodeInterface -MethodName WmiOpcodeInterface -Arguments @{Parameter="WmiOpcodePasswordSetUpdate;"} -ErrorAction Stop
            return $result.Return
        } catch {
            return "Error: $($_.Exception.Message)"
        }
    } elseif ($null -ne $LegacyInterface) {
        # Legacy SetBiosPassword fallback
        try {
            $result = Invoke-CimMethod -InputObject $LegacyInterface -MethodName SetBiosPassword -Arguments @{Parameter="$PasswordType,$CurrentPassword,,ascii,us"} -ErrorAction Stop
            return $result.return
        } catch {
            return "Error: $($_.Exception.Message)"
        }
    }
    return "Error: No WMI interface available"
}

function Set-LenovoFirmwareConfig {
    param($Config)
    $svpPassword = Get-SecureCredential -CredentialName "supervisor"
    $popHddPassword = Get-SecureCredential -CredentialName "pop_hdd"

    if ([string]::IsNullOrEmpty($svpPassword) -and [string]::IsNullOrEmpty($popHddPassword)) {
        Write-Error "Cannot proceed: No valid credentials found in Config folder."
        return $false
    }

    Write-Host "Applying authorized company BIOS configurations..." -ForegroundColor Cyan
    $success = $true

    try {
        $opcodeInterface = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_WmiOpcodeInterface -ErrorAction SilentlyContinue
        $legacyInterface = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_SetBiosPassword -ErrorAction SilentlyContinue
        $saveWmi         = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_SaveBiosSettings -ErrorAction SilentlyContinue

        if ($null -ne $opcodeInterface) {
            Write-Host "  [INFO] Using modern WmiOpcodeInterface (ThinkPad 2020+)" -ForegroundColor DarkCyan
        } elseif ($null -ne $legacyInterface) {
            Write-Host "  [INFO] Using legacy SetBiosPassword interface (older ThinkPad)" -ForegroundColor DarkCyan
        } else {
            Write-Error "  [ERROR] No WMI password interface found on this system!"
            return $false
        }

        # -----------------------------------------------------------------------
        # 1. Clear Power-On Password (POP)
        # Per Lenovo standard: If Supervisor Password exists, use SVP to clear POP.
        # Otherwise use the POP password.
        # -----------------------------------------------------------------------
        Write-Host "  -> Clearing Power-On Password..."
        $popAuth = if (-not [string]::IsNullOrEmpty($svpPassword) -and ($null -ne $Config -and $Config.FirmwareAuth -eq "Enabled")) {
            $svpPassword
        } else {
            $popHddPassword
        }

        if (-not [string]::IsNullOrEmpty($popAuth)) {
            $res = Invoke-LenovoClearPassword -PasswordType "pop" -CurrentPassword $popAuth -OpcodeInterface $opcodeInterface -LegacyInterface $legacyInterface
            Write-Host "     Result (pop): $res"
        }

        # -----------------------------------------------------------------------
        # 2. Clear Hard Disk / NVMe Passwords (All slot variations)
        # -----------------------------------------------------------------------
        Write-Host "  -> Clearing Hard Disk / NVMe Passwords..."
        if (-not [string]::IsNullOrEmpty($popHddPassword)) {
            foreach ($type in @("uhdp1", "mhdp1", "uhdp2", "mhdp2", "udrp1", "adrp1", "uhdp", "mhdp")) {
                $res = Invoke-LenovoClearPassword -PasswordType $type -CurrentPassword $popHddPassword -OpcodeInterface $opcodeInterface -LegacyInterface $legacyInterface
                Write-Host "     Result ($type): $res"
            }
        }

        # -----------------------------------------------------------------------
        # 3. Clear Supervisor Password (PAP) as FINAL step
        # -----------------------------------------------------------------------
        if (-not [string]::IsNullOrEmpty($svpPassword)) {
            Write-Host "  -> Clearing Supervisor / Master BIOS Password..."
            $res = Invoke-LenovoClearPassword -PasswordType "pap" -CurrentPassword $svpPassword -OpcodeInterface $opcodeInterface -LegacyInterface $legacyInterface
            Write-Host "     Result (pap): $res"
        }

        # -----------------------------------------------------------------------
        # 4. Save settings if legacy interface
        # -----------------------------------------------------------------------
        if ($null -eq $opcodeInterface -and $null -ne $saveWmi) {
            Write-Host "  -> Committing BIOS settings (legacy save)..."
            $saveParam = if (-not [string]::IsNullOrEmpty($svpPassword)) { "$svpPassword,ascii,us" } else { ",ascii,us" }
            Invoke-CimMethod -InputObject $saveWmi -MethodName SaveBiosSettings -Arguments @{Parameter=$saveParam} -ErrorAction SilentlyContinue | Out-Null
        }
        
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
