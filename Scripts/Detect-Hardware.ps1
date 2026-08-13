function Get-LenovoHardwareInfo {
    $sysInfo = Get-CimInstance -ClassName Win32_ComputerSystem
    $biosInfo = Get-CimInstance -ClassName Win32_BIOS
    $baseBoard = Get-CimInstance -ClassName Win32_BaseBoard

    # Extract Machine Type from System Model (ThinkPads typically start with the 4-character MT)
    $machineType = ($sysInfo.Model -split " ")[0]
    if ($sysInfo.Model -match "^[0-9A-Z]{4}") {
        $machineType = $sysInfo.Model.Substring(0,4)
    }

    $hardware = [PSCustomObject]@{
        Manufacturer = $sysInfo.Manufacturer
        Model        = $sysInfo.Model
        MachineType  = $machineType
        Serial       = $biosInfo.SerialNumber
        BIOSVersion  = $biosInfo.SMBIOSBIOSVersion
        BIOSDate     = $biosInfo.ReleaseDate
        Storage      = "Unknown"
    }

    # Detect Storage (simple approach for Phase 1)
    $disks = Get-CimInstance -ClassName Win32_DiskDrive
    if ($disks.Count -gt 0) {
        $hardware.Storage = $disks[0].InterfaceType + " - " + $disks[0].Model
    }

    return $hardware
}
