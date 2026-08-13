# Project Roadmap

## Phase 1: Project Setup & Read-Only Detection (Completed)
- [x] Create project directory structure.
- [x] Implement hardware detection (Identify L15 Gen 2 / X13 Gen 2).
- [x] Query BIOS WMI settings for current state.
- [x] Implement USB removal polling loop.
- [x] Build `Startup.ps1` orchestrator for read-only validation.

## Phase 2: Environment Test Preparation (Completed)
- [x] Document WinPE `boot.wim` compilation instructions with necessary WMI/PowerShell prerequisites.

## Phase 3: Configuration & Passwords (Completed)
- [x] Create AES encryption helper script (`Set-Credentials.ps1`).
- [x] Implement `Apply-Configuration.ps1` for BIOS modifications.
- [x] Implement `Verify-Configuration.ps1`.
- [x] Implement `BootOrder.ps1` to restore internal drive boot priority.
- [x] Create automated `Logging.ps1` module.

## Phase 4: Builder Stability & Resilience (Completed)
- [x] Automate releasing OS registry locks (DISM) during WinPE builds.
- [x] Implement dynamic clean workspace fallback (`C:\WinPE_Build`).
- [x] Auto-close File Explorer windows targeting the USB to prevent formatting locks.
- [x] Bypass ADK `MakeWinPEMedia` buggy diskpart logic with robust direct `xcopy` & `bootsect`.
- [x] Create `Clean-USB.bat` utility to safely recover and wipe glitched/locked USB flash drives.

## Phase 5: Production Rollout (Pending)
- [ ] Test the full `Main.ps1` workflow on a single pilot machine.
- [ ] Optimize bilingual UI text for technician throughput.
- [ ] Process 300 devices at an expected rate of 75 machines/day.
