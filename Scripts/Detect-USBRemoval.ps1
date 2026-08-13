function Wait-ForUSBRemoval {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "        PLEASE REMOVE USB FLASH DRIVE" -ForegroundColor Yellow
    Write-Host "   (Unplug USB drive now. Script runs in RAM)   " -ForegroundColor Yellow
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "Pull USB or press Enter/Spacebar to continue..." -ForegroundColor Gray
    Write-Host ""

    $timeoutSeconds = 30
    $startTime = Get-Date

    while ($true) {
        # Check if USB drive was unplugged
        $usbDrives = Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction SilentlyContinue | Where-Object { 
            $_.InterfaceType -eq 'USB' -or $_.MediaType -match 'Removable' 
        }
        
        if ($null -eq $usbDrives -or $usbDrives.Count -eq 0) {
            Write-Host "[OK] USB removal detected. Continuing..." -ForegroundColor Green
            break
        }

        # Allow technician to press Enter or Space to bypass if internal USB peripheral detected
        try {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if ($key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
                    Write-Host "[OK] Manual confirmation received. Continuing..." -ForegroundColor Green
                    break
                }
            }
        } catch {}

        # Auto continue after 30 seconds if left unattended
        if (((Get-Date) - $startTime).TotalSeconds -ge $timeoutSeconds) {
            Write-Host "[OK] Timeout reached. Continuing automatically..." -ForegroundColor Green
            break
        }

        Start-Sleep -Milliseconds 500
    }
}
