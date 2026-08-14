@echo off
setlocal enabledelayedexpansion

title Lenovo USB Password Deleter - Fast Duplicator

echo ========================================================
echo Lenovo USB Password Deleter - Fast Duplicator
echo ========================================================

:: Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo.
    echo [ERROR] Please run this script as Administrator.
    pause
    exit /b 1
)

:: Find WinPE Directory
set "PE_DIR=C:\WinPE_amd64"
if not exist "%PE_DIR%\media\sources\boot.wim" (
    set "PE_DIR=C:\WinPE_Build"
)

if not exist "%PE_DIR%\media\sources\boot.wim" (
    echo [ERROR] Pre-built WinPE image not found! 
    echo Please run setup.bat at least once to build the master image.
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
    echo.
    echo [ERROR] No USB Flash Drive detected!
    pause
    exit /b 1
)

echo.
echo ========================================================
echo Auto-Detected USB Drive: %TARGET_DRIVE%
echo ========================================================
echo WARNING: This will overwrite files on %TARGET_DRIVE%
echo ========================================================
pause

echo [INFO] Formatting %TARGET_DRIVE% to FAT32...
powershell -NoProfile -Command "Format-Volume -DriveLetter '%TARGET_DRIVE:~0,1%' -FileSystem FAT32 -NewFileSystemLabel 'WINPE' -Force -Confirm:$false"

echo [INFO] Copying WinPE files directly to %TARGET_DRIVE%...
xcopy /s /e /y /h /i "%PE_DIR%\media\*" "%TARGET_DRIVE%\" >nul

echo [INFO] Writing Boot Sector to %TARGET_DRIVE%...
set "ADK_PATH=C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit"
"%ADK_PATH%\Deployment Tools\amd64\BCDBoot\bootsect.exe" /nt60 %TARGET_DRIVE% /force /mbr >nul

echo.
echo ========================================================
echo SUCCESS: Bootable WinPE USB is ready on %TARGET_DRIVE%!
echo ========================================================
pause
