# Lenovo USB Password Deleter & Configurator

A production-grade, offline UEFI WinPE USB automation tool designed to manage BIOS passwords and configurations for Lenovo ThinkPad laptops (specifically L15 Gen 2 and X13 Gen 2).

## Features
- **Zero-Touch RAM Execution**: Boot from USB, remove the USB when prompted, and the script runs entirely in RAM.
- **Hardware Validation**: Strictly limits operations to approved Lenovo Machine Types.
- **Secure Credentials**: Uses AES-256 encrypted configuration files instead of plain-text passwords.
- **Idempotent Operations**: Checks current WMI settings before applying changes to prevent unnecessary writes.
- **Automated Logging**: Generates an audit trail of every machine processed.

## Directory Structure
- `Scripts/`: Contains the core PowerShell automation scripts (`Main.ps1`, WMI detectors, Config appliers).
- `Lenovo/Tools/`: Contains utilities like `Set-Credentials.ps1` for password encryption.
- `Config/`: Stores the encrypted `supervisor.txt` credentials file.
- `Logs/`: Stores `audit.csv` for tracking success/failures.

## Usage
Refer to `CheatSheet.md` for quick commands and `Roadmap.md` for project status.
