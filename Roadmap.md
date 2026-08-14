# Project Roadmap

## Phase 1: Project Setup & Read-Only Detection (Completed)
- [x] Create project directory structure.
- [x] Implement hardware detection (Identify L15 Gen 2 / X13 Gen 2 / ThinkCentre M90q).
- [x] Query BIOS WMI settings for current state.
- [x] Implement USB removal polling loop for zero-touch workflow.
- [x] Build orchestrator for read-only validation.

## Phase 2: Environment & Builder Stability (Completed)
- [x] Document WinPE `boot.wim` compilation instructions with necessary WMI/PowerShell prerequisites.
- [x] Automate releasing OS registry locks (DISM) during WinPE builds.
- [x] Implement dynamic clean workspace fallback (`C:\WinPE_Build`).
- [x] Auto-close File Explorer windows targeting the USB to prevent formatting locks.
- [x] Fix recursive build bloat in `setup.bat` (resolving FAT32 4GB limit).
- [x] Create `Clean-USB.bat` utility to safely recover and wipe glitched/locked USB flash drives.
- [x] Implement `Duplicate-USB.bat` for fast mass deployment.

## Phase 3: Password Deletion Engine & Architecture (Completed)
- [x] Create AES-256 encryption helper script (`Set-Credentials.ps1`).
- [x] Migrate to modern `Lenovo_WmiOpcodeInterface` standard for ThinkPad 2020+ and ThinkCentre Desktops.
- [x] Implement authoritative password state bitmask detection (`Lenovo_BiosPasswordSettings`).
- [x] Resolve Error 0191 collision by isolating password deletion from general BIOS setting changes.
- [x] Implement M.2 / NVMe Drive 1 Admin & User password clearance (`adrp1`, `udrp1`, `uhdp1`, `mhdp1`, `uhdp2`, `mhdp2`).
- [x] Add ThinkCentre M90q desktop administrative session authorization (`WmiOpcodePasswordAdmin`).
- [x] Resolve HDD Access Denied issues by actively injecting the Supervisor Password as an authorization parameter.
- [x] Implement automated `Logging.ps1` module writing telemetry to `audit.csv`.
- [x] Intercept and append exact WMI error codes to `audit.csv` for precise debugging.
- [x] Create `Mock-WMI-Simulator.ps1` to test BIOS interactions on non-Lenovo hardware.

## Phase 4: Production Rollout & Scaling (In Progress)
- [x] Verified Supervisor Password deletion on pilot ThinkPad and ThinkCentre units.
- [x] Verified Power-On Password (POP) removal.
- [x] Verified M.2 / NVMe Drive 1 storage password clearance.
- [ ] Mass deployment across target batch (target rate: 75+ machines/day).
