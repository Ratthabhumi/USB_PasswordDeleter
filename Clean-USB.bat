@echo off
setlocal enabledelayedexpansion

title USB Disk Cleaner - G:
echo ========================================================
echo USB Disk Cleaner
echo ========================================================

:: Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo.
    echo [ERROR] Please run this script as Administrator.
    echo Right-click Clean-USB.bat and select "Run as administrator".
    echo.
    pause
    exit /b 1
)

echo.
echo Please enter the Disk Number of your USB Flash Drive.
echo You can find this by running "diskpart" -^> "list disk"
echo WARNING: IF YOU ENTER THE WRONG NUMBER, YOU WILL WIPE YOUR HARD DRIVE!
set /p DISKNUM="Enter Disk Number (e.g. 1, 2, 3): "

if "%DISKNUM%"=="" (
    echo No disk selected. Exiting.
    pause
    exit /b 1
)

echo.
echo Cleaning Disk %DISKNUM%...

(
echo select disk %DISKNUM%
echo clean
echo create partition primary
echo format fs=fat32 quick
echo assign
echo exit
) > "%TEMP%\clean_usb.txt"

diskpart /s "%TEMP%\clean_usb.txt"

if %errorLevel% NEQ 0 (
    echo.
    echo [ERROR] Failed to clean the disk!
    pause
    exit /b 1
)

echo.
echo ========================================================
echo SUCCESS: Disk %DISKNUM% has been completely wiped and formatted!
echo You can now run setup.bat again.
echo ========================================================
pause
