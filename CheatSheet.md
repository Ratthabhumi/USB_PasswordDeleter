# Lenovo WMI & WinPE Cheat Sheet

## 1. Credential Management
Generate an AES-encrypted password file (`Config\supervisor.txt`):
```powershell
.\Lenovo\Tools\Set-Credentials.ps1
```

## 2. Compile WinPE Boot Media (Run as Admin)
```cmd
:: 1. Copy base WinPE
copype amd64 C:\WinPE_amd64

:: 2. Mount Image
Dism /Mount-Image /ImageFile:"C:\WinPE_amd64\media\sources\boot.wim" /index:1 /MountDir:"C:\WinPE_amd64\mount"

:: 3. Inject Required Packages (Must inject both neutral and en-us versions)
Dism /Add-Package /Image:"C:\WinPE_amd64\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-WMI.cab"
Dism /Add-Package /Image:"C:\WinPE_amd64\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-NetFX.cab"
Dism /Add-Package /Image:"C:\WinPE_amd64\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-Scripting.cab"
Dism /Add-Package /Image:"C:\WinPE_amd64\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-PowerShell.cab"

:: 4. Inject Project Files
xcopy /s /e "C:\Users\Ratthabhumi\Desktop\CO-OP_Project\USB_PasswordDeleter\*" "C:\WinPE_amd64\mount\USB_PasswordDeleter\"

:: 5. Set Startup Script
echo powershell.exe -ExecutionPolicy Bypass -File X:\USB_PasswordDeleter\Scripts\Main.ps1 >> C:\WinPE_amd64\mount\Windows\System32\startnet.cmd

:: 6. Unmount and Save
Dism /Unmount-Image /MountDir:"C:\WinPE_amd64\mount" /commit

:: 7. Create USB (Replace F: with your USB drive letter)
MakeWinPEMedia /UFD C:\WinPE_amd64 F:
```

## 3. Useful Lenovo WMI Queries
Read all current settings:
```powershell
Get-CimInstance -Namespace root\wmi -ClassName Lenovo_BiosSetting | Select-Object CurrentSetting
```

Check Password States:
```powershell
Get-CimInstance -Namespace root\wmi -ClassName Lenovo_BiosPasswordSettings
```
*(PasswordState: 0=None, 1=POP, 2=Supervisor, 3=Both)*
