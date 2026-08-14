function Wait-ForUSBRemoval {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "        USB LOGGING MODE ENABLED" -ForegroundColor Yellow
    Write-Host "   (Please leave USB plugged in to save logs)   " -ForegroundColor Yellow
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host ""
    
    # We no longer wait for the USB to be unplugged.
    # The script will execute immediately and save logs to the USB at the end.
    Start-Sleep -Seconds 2
}
