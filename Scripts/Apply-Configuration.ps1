function Get-SecureCredential {
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $configPath = Join-Path $scriptPath "..\Config\supervisor.txt"

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
        $secureString = $encryptedStr | ConvertTo-SecureString -Key $aesKey
        
        # Convert SecureString back to plain text strictly for WMI API injection in RAM
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
        $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        
        return $plain
    } catch {
        Write-Warning "Failed to decrypt the supervisor password."
        return $null
    }
}

function Set-LenovoFirmwareConfig {
    $password = Get-SecureCredential
    if ($null -eq $password) {
        Write-Error "Cannot proceed without supervisor credentials."
        return $false
    }

    Write-Host "Applying authorized company configurations..."
    $success = $true

    try {
        $setWmi = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_SetBiosSetting
        $saveWmi = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_SaveBiosSettings

        # 1. Example: Disable Secure Boot (or whatever the standard is)
        # Format: Setting,Value,Password,Encoding,KbdLang
        $cmd = "SecureBoot,Disable,$password,ascii,us"
        Invoke-CimMethod -InputObject $setWmi -MethodName SetBiosSetting -Arguments @{Parameter=$cmd} | Out-Null
        
        # 2. Clear Power On Password if present
        $cmdPop = "PowerOnPassword,Disable,$password,ascii,us"
        Invoke-CimMethod -InputObject $setWmi -MethodName SetBiosSetting -Arguments @{Parameter=$cmdPop} | Out-Null

        # NOTE: Add more settings here based on the exact corporate requirements
        # e.g. Absolute Persistence, Virtualization, etc.

        # Save all applied settings
        Invoke-CimMethod -InputObject $saveWmi -MethodName SaveBiosSettings -Arguments @{Parameter="$password,ascii,us"} | Out-Null
        
        Write-Host "[ OK ] Settings applied successfully." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to apply BIOS settings: $($_.Exception.Message)"
        $success = $false
    }

    # Security: Ensure we wipe the password variable from RAM
    Remove-Variable -Name password -ErrorAction SilentlyContinue
    
    return $success
}
