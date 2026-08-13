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
    
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
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
    
    # Attempt to copy to internal disk if available (e.g. C: or D:)
    # Because WinPE is volatile (X: drive is lost on shutdown)
    $internalLogVol = Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter -ne $null } | Select-Object -First 1
    if ($null -ne $internalLogVol) {
        $internalPath = "$($internalLogVol.DriveLetter):\Logs"
        if (-not (Test-Path $internalPath)) { 
            New-Item -ItemType Directory -Path $internalPath -Force | Out-Null 
        }
        Copy-Item $ramLogPath -Destination "$internalPath\audit.csv" -Force -ErrorAction SilentlyContinue
    }
}
