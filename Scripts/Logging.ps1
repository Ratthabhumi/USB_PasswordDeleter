function Write-AuditLog {
    param (
        [string]$Serial,
        [string]$MachineType,
        [string]$Model,
        [string]$BIOSVersion,
        [string]$Storage,
        [string]$Result,
        [string]$ErrorDetail
    )
    
    $timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
    $logLine = "$timestamp,$Serial,$MachineType,$Model,$BIOSVersion,$Storage,$Result,$ErrorDetail"
    
    $scriptDir = $PSScriptRoot
    $ramLogPath = Join-Path $scriptDir "..\Logs\audit.csv"
    $logDir = Split-Path -Parent $ramLogPath
    
    # Ensure Logs folder exists
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    if (-not (Test-Path $ramLogPath)) {
        "Timestamp,Serial,MachineType,Model,BIOSVersion,Storage,Result,Error" | Out-File $ramLogPath -Encoding UTF8
    }
    
    $logLine | Out-File $ramLogPath -Append -Encoding UTF8
    
    # Save directly to the USB Flash Drive to accumulate logs
    $usbVol = Get-Volume | Where-Object { $_.DriveType -eq 'Removable' -and $_.DriveLetter -ne $null } | Select-Object -First 1
    
    if ($null -ne $usbVol) {
        $usbLogPath = "$($usbVol.DriveLetter):\audit.csv"
        
        # If the file doesn't exist on USB yet, add the header
        if (-not (Test-Path $usbLogPath)) {
            "Timestamp,Serial,MachineType,Model,BIOSVersion,Storage,Result,Error" | Out-File $usbLogPath -Encoding UTF8
        }
        
        # Append the new log line to the USB file
        $logLine | Out-File $usbLogPath -Append -Encoding UTF8
    } else {
        # Fallback to internal drive if USB is missing
        $internalLogVol = Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter -ne $null } | Select-Object -First 1
        if ($null -ne $internalLogVol) {
            $internalPath = "$($internalLogVol.DriveLetter):\Logs"
            if (-not (Test-Path $internalPath)) { 
                New-Item -ItemType Directory -Path $internalPath -Force | Out-Null 
            }
            Copy-Item $ramLogPath -Destination "$internalPath\audit.csv" -Force -ErrorAction SilentlyContinue
        }
    }
}
