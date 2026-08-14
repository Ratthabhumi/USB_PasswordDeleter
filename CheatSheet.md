# Lenovo WMI & WinPE Automation Cheat Sheet

## 1. Credential Management
Generate AES-256 encrypted password files (`Config\supervisor.txt` & `Config\pop_hdd.txt`):
```powershell
powershell -ExecutionPolicy Bypass -File .\Lenovo\Tools\Set-Credentials.ps1
```

## 2. Automated USB Builder (Run as Admin)
Simply right-click `setup.bat` and select **"Run as administrator"**.

To duplicate the master WinPE USB to another flash drive:
Right-click `Duplicate-USB.bat` and select **"Run as administrator"**.

## 3. Lenovo WMI Architecture Reference

### Modern Opcode Interface (ThinkPad 2020+ & ThinkCentre Desktops)
- WMI Namespace: `root\wmi`
- Primary Class: `Lenovo_WmiOpcodeInterface`
- Sequence to clear a password:
  ```powershell
  # 1. For ThinkCentre / ThinkStation desktops only:
  Invoke-CimMethod -ClassName Lenovo_WmiOpcodeInterface -MethodName WmiOpcodeInterface -Arguments @{Parameter="WmiOpcodePasswordAdmin:<SVP>;"}

  # 2. Set Password Type:
  Invoke-CimMethod -ClassName Lenovo_WmiOpcodeInterface -MethodName WmiOpcodeInterface -Arguments @{Parameter="WmiOpcodePasswordType:<type>;"}

  # 3. Supply Current Password:
  Invoke-CimMethod -ClassName Lenovo_WmiOpcodeInterface -MethodName WmiOpcodeInterface -Arguments @{Parameter="WmiOpcodePasswordCurrent01:<current_password>;"}

  # 4. Supply Empty New Password (to clear):
  Invoke-CimMethod -ClassName Lenovo_WmiOpcodeInterface -MethodName WmiOpcodeInterface -Arguments @{Parameter="WmiOpcodePasswordNew01:;"}

  # 5. Commit to NVRAM:
  Invoke-CimMethod -ClassName Lenovo_WmiOpcodeInterface -MethodName WmiOpcodeInterface -Arguments @{Parameter="WmiOpcodePasswordSetUpdate;"}
  ```

### Password Type Identifiers (`WmiOpcodePasswordType`)
- `pap`: Supervisor / Master BIOS Password
- `pop`: Power-On Password
- `udrp1` / `adrp1`: M.2 / NVMe Drive 1 User & Admin Password (ThinkCentre & ThinkPad)
- `uhdp1` / `mhdp1`: Primary Storage User & Master Password
- `uhdp2` / `mhdp2`: Secondary Storage User & Master Password

### Checking Password States (`Lenovo_BiosPasswordSettings`)
```powershell
(Get-CimInstance -Namespace root\wmi -ClassName Lenovo_BiosPasswordSettings).PasswordState
```
**Bitmask Reference:**
- `0`: No passwords set
- `1`: Power-On Password (POP) only
- `2`: Supervisor Password (SVP) only
- `3`: POP + SVP
- `4`: Hard Disk / NVMe Password (HDP) only
- `5`: POP + HDP
- `6`: SVP + HDP
- `7`: POP + SVP + HDP
- `64`–`71`: Systems with System Management Password (SMP)

### Critical Firmware Constraints & Troubleshooting
1. **Error 0191 (System Security - Access Denied / Invalid Change):**
   - Occurs when attempting to modify general BIOS Settings (e.g. SecureBoot, BootOrder) in the same power cycle as password deletions. Keep password deletion operations isolated.
   - Occurs when attempting to delete a Hard Disk Password (HDP) without providing the Supervisor Password (SVP) as an authorization parameter (e.g., `hdp,<hdd_pwd>,,,ascii,us,<svp_pwd>`).
   - Occurs on ThinkCentre Desktops if `WmiOpcodePasswordAdmin` is not called before clearing M.2 `adrp1` slots.
2. **Reboot Requirement:** Password deletions via OpcodeInterface are queued in NVRAM and finalized upon the **next system reboot**.
3. **Corrupted USB Drive?** Run `Clean-USB.bat` as Administrator to wipe and restore partition structures.
