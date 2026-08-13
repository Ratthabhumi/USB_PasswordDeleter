function Wait-ForUSBRemoval {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "        PLEASE REMOVE USB DRIVE" -ForegroundColor Yellow
    Write-Host "        ถอด Flash Drive ออกได้เลย" -ForegroundColor Yellow
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host ""

    # In WinPE, the boot USB is usually detected as Removable or USB Interface
    while ($true) {
        $usbDrives = Get-CimInstance -ClassName Win32_DiskDrive | Where-Object { $_.InterfaceType -eq 'USB' -or $_.MediaType -match 'Removable' }
        
        if ($null -eq $usbDrives -or $usbDrives.Count -eq 0) {
            Write-Host "[ OK ] USB removed. Continuing automatically..." -ForegroundColor Green
            break
        }
        Start-Sleep -Seconds 2
    }
}
