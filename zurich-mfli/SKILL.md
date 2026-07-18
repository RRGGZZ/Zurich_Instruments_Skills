---
name: zurich-mfli
description: Discover, inspect, read, sample, and explicitly control Zurich Instruments MFLI lock-in amplifiers through LabOne on Windows. Use for MFLI connection checks, device and server status, node discovery, parameter reads, demodulator samples, or carefully approved node writes. Default to read-only operations and require fresh user confirmation before every write.
---

# Zurich MFLI

Prefer `scripts/mfli_toolkit.py` with the isolated environment at `D:\HS_AFM\.venv`; it uses the cloned official `zhinst-toolkit` checkout. Use `scripts/mfli.ps1` as the compatibility backend when that environment is unavailable.

## Workflow

1. Run `scripts/mfli_toolkit.py discover` before selecting a device; fall back to `mfli.ps1 discover` if the toolkit environment is unavailable.
2. If exactly one MFLI is visible, use it. Otherwise ask the user to select a device serial.
3. Run `status` and surface any API/server version mismatch.
4. Use `list`, `read`, or `sample` without requesting confirmation because these operations are read-only.
5. Before `write`, read the node metadata and current value, then show the exact device, node, old value, and proposed value.
6. Ask for explicit confirmation in the current turn. A request to connect, measure, configure generally, or a previous approval is not write approval.
7. After confirmation, run `write` with both `-AllowWrite` and `-ConfirmDevice <serial>`. Read back the value and report the result.

## Commands

Run from the skill directory with the official toolkit environment:

```powershell
& 'D:\HS_AFM\.venv\Scripts\python.exe' .\scripts\mfli_toolkit.py discover
& 'D:\HS_AFM\.venv\Scripts\python.exe' .\scripts\mfli_toolkit.py status --device DEV5617
& 'D:\HS_AFM\.venv\Scripts\python.exe' .\scripts\mfli_toolkit.py read --device DEV5617 --node '/DEV5617/DEMODS/0/RATE'
& 'D:\HS_AFM\.venv\Scripts\python.exe' .\scripts\mfli_toolkit.py sample --device DEV5617 --demod 0
& 'D:\HS_AFM\.venv\Scripts\python.exe' .\scripts\mfli_toolkit.py write --device DEV5617 --node '/DEV5617/DEMODS/0/RATE' --value 1000 --allow-write --confirm-device DEV5617
```

The compatibility PowerShell commands are:

```powershell
.\scripts\mfli.ps1 discover
.\scripts\mfli.ps1 status -Device DEV5617
.\scripts\mfli.ps1 list -Device DEV5617 -Node '/DEV5617/DEMODS/0/*'
.\scripts\mfli.ps1 read -Device DEV5617 -Node '/DEV5617/DEMODS/0/RATE'
.\scripts\mfli.ps1 sample -Device DEV5617 -Demod 0
.\scripts\mfli.ps1 write -Device DEV5617 -Node '/DEV5617/DEMODS/0/RATE' -Value 1000 -AllowWrite -ConfirmDevice DEV5617
```

All commands emit JSON. Both adapters discover the device server address automatically. The toolkit adapter accepts `--server-host` and `--port`; the compatibility adapter accepts `-ServerHost`, `-Port`, or `-ApiLevel`.

## Safety Rules

- Default to read-only commands.
- Never call factory preset/reset, calibration, firmware update, AWG upload, device disconnect, or Data Server shutdown unless the user explicitly requests that exact action.
- Treat signal-output enable, output amplitude/range, current-input range, and auxiliary-output changes as energized-hardware operations. Restate the electrical effect before asking for confirmation.
- Refuse writes when LabOne client and server versions differ. Only use `-AllowVersionMismatch` after warning the user and receiving explicit approval for that additional risk.
- Do not write wildcard paths.
- Do not silently connect a device to a different Data Server when discovery reports it is already in use.
- Preserve the user's existing LabOne session and settings.

## References

Read `references/environment.md` when troubleshooting installation, server selection, version compatibility, or the local source checkout.
