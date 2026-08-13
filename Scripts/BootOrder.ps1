function Set-InternalBootPriority {
    $password = Get-SecureCredential # Uses the same helper from Apply-Configuration.ps1
    if ($null -eq $password) {
        return $false
    }

    Write-Host "Restoring normal internal-drive boot priority..."
    try {
        $setWmi = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_SetBiosSetting
        $saveWmi = Get-CimInstance -Namespace "root\wmi" -ClassName Lenovo_SaveBiosSettings

        # Standard Lenovo BootOrder strings usually include: USBCD, USBHDD, HDD0, PCILAN
        # We enforce HDD0 (Internal Drive) to be the first option.
        $newBootOrder = "HDD0:USBCD:USBHDD:PCILAN"
        
        $cmd = "BootOrder,$newBootOrder,$password,ascii,us"
        Invoke-CimMethod -InputObject $setWmi -MethodName SetBiosSetting -Arguments @{Parameter=$cmd} | Out-Null
        
        # Save Boot Order changes
        Invoke-CimMethod -InputObject $saveWmi -MethodName SaveBiosSettings -Arguments @{Parameter="$password,ascii,us"} | Out-Null
        
        Write-Host "[ OK ] Boot priority restored to internal drive." -ForegroundColor Green
        Remove-Variable -Name password -ErrorAction SilentlyContinue
        return $true
    } catch {
        Write-Warning "Failed to modify BootOrder: $($_.Exception.Message)"
        Remove-Variable -Name password -ErrorAction SilentlyContinue
        return $false
    }
}
