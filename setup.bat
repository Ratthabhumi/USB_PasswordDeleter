@echo off
setlocal enabledelayedexpansion

echo ========================================================
echo Lenovo USB Password Deleter - WinPE Builder
echo ========================================================

:: Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo [ERROR] Please run this script as Administrator.
    echo Right-click setup.bat and select "Run as administrator".
    pause
    exit /b 1
)

:: Get target drive letter automatically
echo Scanning for Removable USB Drives...
set "TARGET_DRIVE="
for /f "usebackq tokens=*" %%A in (`powershell -NoProfile -Command "Get-Volume | Where-Object { $_.DriveType -eq 'Removable' -and $_.DriveLetter -ne $null } | Select-Object -ExpandProperty DriveLetter -First 1"`) do (
    set "TARGET_DRIVE=%%A:"
)

if "%TARGET_DRIVE%"=="" (
    echo [ERROR] No USB Flash Drive detected! Please insert a USB drive and try again.
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
    echo [ERROR] Windows ADK not found at default location.
    echo Please install "Windows ADK" and "Windows PE add-on".
    pause
    exit /b 1
)

:: Initialize ADK Environment
call "%ADK_PATH%\Deployment Tools\DandISetEnv.bat"

set "PE_DIR=C:\WinPE_amd64"
set "MOUNT_DIR=%PE_DIR%\mount"

:: Clean up previous build if exists
if exist "%PE_DIR%" (
    echo Cleaning up previous WinPE build...
    dism /Unmount-Image /MountDir:"%MOUNT_DIR%" /discard >nul 2>&1
    rd /s /q "%PE_DIR%"
)

echo.
echo [1/6] Copying base WinPE files...
call copype amd64 "%PE_DIR%"

echo.
echo [2/6] Mounting WinPE image...
dism /Mount-Image /ImageFile:"%PE_DIR%\media\sources\boot.wim" /index:1 /MountDir:"%MOUNT_DIR%"

echo.
echo [3/6] Injecting Required Packages (WMI, NetFX, Scripting, PowerShell)...
set "OC_PATH=%ADK_PATH%\Windows Preinstallation Environment\amd64\WinPE_OCs"

dism /Add-Package /Image:"%MOUNT_DIR%" /PackagePath:"%OC_PATH%\WinPE-WMI.cab" /Quiet /NoRestart
dism /Add-Package /Image:"%MOUNT_DIR%" /PackagePath:"%OC_PATH%\en-us\WinPE-WMI_en-us.cab" /Quiet /NoRestart
dism /Add-Package /Image:"%MOUNT_DIR%" /PackagePath:"%OC_PATH%\WinPE-NetFX.cab" /Quiet /NoRestart
dism /Add-Package /Image:"%MOUNT_DIR%" /PackagePath:"%OC_PATH%\en-us\WinPE-NetFX_en-us.cab" /Quiet /NoRestart
dism /Add-Package /Image:"%MOUNT_DIR%" /PackagePath:"%OC_PATH%\WinPE-Scripting.cab" /Quiet /NoRestart
dism /Add-Package /Image:"%MOUNT_DIR%" /PackagePath:"%OC_PATH%\en-us\WinPE-Scripting_en-us.cab" /Quiet /NoRestart
dism /Add-Package /Image:"%MOUNT_DIR%" /PackagePath:"%OC_PATH%\WinPE-PowerShell.cab" /Quiet /NoRestart
dism /Add-Package /Image:"%MOUNT_DIR%" /PackagePath:"%OC_PATH%\en-us\WinPE-PowerShell_en-us.cab" /Quiet /NoRestart

echo.
echo [4/6] Copying Project Files to WinPE...
set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"
xcopy /s /e /y "%PROJECT_DIR%\*" "%MOUNT_DIR%\USB_PasswordDeleter\"

echo.
echo [5/6] Configuring startup script...
echo powershell.exe -ExecutionPolicy Bypass -File X:\USB_PasswordDeleter\Scripts\Main.ps1 >> "%MOUNT_DIR%\Windows\System32\startnet.cmd"

echo.
echo [6/6] Unmounting and saving image...
dism /Unmount-Image /MountDir:"%MOUNT_DIR%" /commit

echo.
echo ========================================================
echo Building USB Boot Media on %TARGET_DRIVE%
echo ========================================================
:: MakeWinPEMedia will prompt to confirm formatting
call MakeWinPEMedia /UFD "%PE_DIR%" %TARGET_DRIVE%

echo.
echo Process Completed.
pause
