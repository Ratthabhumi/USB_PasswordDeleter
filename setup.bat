@echo off
setlocal enabledelayedexpansion

title Lenovo USB Password Deleter - WinPE Builder

echo ========================================================
echo Lenovo USB Password Deleter - WinPE Builder
echo ========================================================

:: Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo.
    echo [ERROR] Please run this script as Administrator.
    echo Right-click setup.bat and select "Run as administrator".
    echo.
    pause
    exit /b 1
)

:: Save original project directory
set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"
cd /d "%PROJECT_DIR%"

:: Check credentials
if not exist "%PROJECT_DIR%\Config\supervisor.txt" (
    echo.
    echo [WARNING] No credentials found in Config\supervisor.txt!
    echo If target machines require password deletion, please run:
    echo   powershell -File Lenovo\Tools\Set-Credentials.ps1
    echo before building the USB.
    echo.
)

:: Get target drive letter automatically
echo Scanning for Removable USB Drives...
set "TARGET_DRIVE="
for /f "usebackq tokens=*" %%A in (`powershell -NoProfile -Command "Get-Volume | Where-Object { $_.DriveType -eq 'Removable' -and $_.DriveLetter -ne $null } | Select-Object -ExpandProperty DriveLetter -First 1"`) do (
    set "TARGET_DRIVE=%%A:"
)

if "%TARGET_DRIVE%"=="" (
    echo.
    echo [ERROR] No USB Flash Drive detected! Please insert a USB drive and try again.
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================================
echo Auto-Detected USB Drive: %TARGET_DRIVE%
echo ========================================================
echo WARNING: ALL DATA ON %TARGET_DRIVE% WILL BE ERASED!
echo ========================================================
pause

:: Locate ADK
set "ADK_PATH=C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit"
if not exist "%ADK_PATH%\Deployment Tools\DandISetEnv.bat" (
    echo.
    echo [ERROR] Windows ADK not found at default location.
    echo Please run Install-ADK.ps1 to install Windows ADK and WinPE add-on.
    echo.
    pause
    exit /b 1
)

:: Initialize ADK Environment
call "%ADK_PATH%\Deployment Tools\DandISetEnv.bat"
cd /d "%PROJECT_DIR%"

set "PE_DIR=C:\WinPE_amd64"
set "MOUNT_DIR=%PE_DIR%\mount"

:: Comprehensive cleanup of previous builds and locked mountpoints
echo.
echo Cleaning up previous WinPE builds and releasing file locks...
dism /Unmount-Image /MountDir:"%MOUNT_DIR%" /discard >nul 2>&1
dism /Cleanup-Wim >nul 2>&1
dism /Cleanup-Mountpoints >nul 2>&1

if exist "%PE_DIR%" (
    rd /s /q "%PE_DIR%" >nul 2>&1
)

if exist "%PE_DIR%" (
    echo.
    echo [ERROR] Unable to remove existing directory %PE_DIR%.
    echo Some files are locked by another process.
    echo Please close any open File Explorer windows and try again.
    echo.
    pause
    exit /b 1
)

echo.
echo [1/6] Copying base WinPE files...
call copype amd64 "%PE_DIR%"
if %errorLevel% NEQ 0 (
    echo.
    echo [ERROR] copype failed to initialize WinPE directory.
    pause
    exit /b 1
)

echo.
echo [2/6] Mounting WinPE image...
dism /Mount-Image /ImageFile:"%PE_DIR%\media\sources\boot.wim" /index:1 /MountDir:"%MOUNT_DIR%"
if %errorLevel% NEQ 0 (
    echo.
    echo [ERROR] DISM failed to mount boot.wim.
    pause
    exit /b 1
)

echo.
echo [3/6] Injecting Required Packages...
set "OC_PATH=%ADK_PATH%\Windows Preinstallation Environment\amd64\WinPE_OCs"

dism /Add-Package /Image:"%MOUNT_DIR%" /PackagePath:"%OC_PATH%\WinPE-WMI.cab" /Quiet /NoRestart
dism /Add-Package /Image:"%MOUNT_DIR%" /PackagePath:"%OC_PATH%\en-us\WinPE-WMI_en-us.cab" /Quiet /NoRestart
dism /Add-Package /Image:"%MOUNT_DIR%" /PackagePath:"%OC_PATH%\WinPE-NetFX.cab" /Quiet /NoRestart
dism /Add-Package /Image:"%MOUNT_DIR%" /PackagePath:"%OC_PATH%\en-us\WinPE-NetFX_en-us.cab" /Quiet /NoRestart
dism /Add-Package /Image:"%MOUNT_DIR%" /PackagePath:"%OC_PATH%\WinPE-Scripting.cab" /Quiet /NoRestart
dism /Add-Package /Image:"%MOUNT_DIR%" /PackagePath:"%OC_PATH%\en-us\WinPE-Scripting_en-us.cab" /Quiet /NoRestart
dism /Add-Package /Image:"%MOUNT_DIR%" /PackagePath:"%OC_PATH%\WinPE-PowerShell.cab" /Quiet /NoRestart
dism /Add-Package /Image:"%MOUNT_DIR%" /PackagePath:"%OC_PATH%\en-us\WinPE-PowerShell_en-us.cab" /Quiet /NoRestart

if exist "%OC_PATH%\WinPE-StorageWMI.cab" (
    dism /Add-Package /Image:"%MOUNT_DIR%" /PackagePath:"%OC_PATH%\WinPE-StorageWMI.cab" /Quiet /NoRestart
    dism /Add-Package /Image:"%MOUNT_DIR%" /PackagePath:"%OC_PATH%\en-us\WinPE-StorageWMI_en-us.cab" /Quiet /NoRestart
)

echo.
echo [4/6] Copying Project Files to WinPE...
xcopy /s /e /y "%PROJECT_DIR%\*" "%MOUNT_DIR%\USB_PasswordDeleter\" >nul
if %errorLevel% NEQ 0 (
    echo.
    echo [ERROR] Failed to copy project files to WinPE image.
    pause
    exit /b 1
)

echo.
echo [5/6] Configuring startup script...
echo powershell.exe -ExecutionPolicy Bypass -File X:\USB_PasswordDeleter\Scripts\Main.ps1 >> "%MOUNT_DIR%\Windows\System32\startnet.cmd"

echo.
echo [6/6] Unmounting and saving image...
dism /Unmount-Image /MountDir:"%MOUNT_DIR%" /commit
if %errorLevel% NEQ 0 (
    echo.
    echo [ERROR] DISM failed to commit and unmount image.
    pause
    exit /b 1
)

echo.
echo ========================================================
echo Building USB Boot Media on %TARGET_DRIVE%
echo ========================================================
call MakeWinPEMedia /UFD "%PE_DIR%" %TARGET_DRIVE%
if %errorLevel% NEQ 0 (
    echo.
    echo [ERROR] MakeWinPEMedia failed to write to %TARGET_DRIVE%.
    pause
    exit /b 1
)

echo.
echo ========================================================
echo SUCCESS: Bootable WinPE USB is ready on %TARGET_DRIVE%!
echo ========================================================
pause
