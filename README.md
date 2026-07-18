# Zurich Instruments Skills

[简体中文](README.zh-CN.md)

Codex skill for safely discovering, inspecting, reading, sampling, and explicitly controlling Zurich Instruments MFLI lock-in amplifiers through LabOne.

## Contents

- [`zurich-mfli/`](zurich-mfli/): the skill definition, safety workflow, references, and adapters.
- [`mfli_toolkit.py`](zurich-mfli/scripts/mfli_toolkit.py): preferred adapter using the official `zhinst-toolkit` Python API.
- [`mfli.ps1`](zurich-mfli/scripts/mfli.ps1): Windows compatibility adapter using the LabOne .NET API.
- No virtual environment, instrument data, credentials, or third-party source tree is committed.

## Requirements

- Windows and PowerShell.
- LabOne installed and able to see the MFLI in its Web UI.
- Python 3.10 or newer.
- [`uv`](https://docs.astral.sh/uv/) is recommended for creating and maintaining the virtual environment.
- Network access to the Data Server, normally port `8004`.

The official toolkit requires LabOne 25.04 or newer. Keep the Python API and the instrument Data Server on the same LabOne release before performing normal writes.

## Why `.venv` Is Required

The preferred adapter imports `zhinst.toolkit`, `zhinst.core`, and their dependencies. These packages must be installed in an isolated environment. The documented layout is:

```text
D:\HS_AFM\
  .venv\                  # Python runtime used by the skill
  zhinst-toolkit\         # official Zurich Instruments checkout
  Zurich_Instruments_Skills\
    zurich-mfli\          # this skill
```

The `.venv` directory is local machine state and is intentionally excluded by `.gitignore`. Do not commit it. You may use another root directory, but update the paths in your commands accordingly.

## Installation With `uv` (Recommended)

The following PowerShell commands use `D:\HS_AFM` as the root. Replace `$Root` when using another location.

```powershell
$Root = 'D:\HS_AFM'
$Repo = Join-Path $Root 'Zurich_Instruments_Skills'
$Toolkit = Join-Path $Root 'zhinst-toolkit'
$Python = Join-Path $Root '.venv\Scripts\python.exe'

# Install uv once if it is not already available.
# winget install --id=astral-sh.uv -e

git clone https://github.com/RRGGZZ/Zurich_Instruments_Skills.git $Repo
git clone https://github.com/zhinst/zhinst-toolkit.git $Toolkit

uv venv (Join-Path $Root '.venv') --python 3.12
uv pip install --python $Python -e $Toolkit
```

`uv venv` creates the required `.venv`; `uv pip install -e` installs the official toolkit in editable mode, including `zhinst-core`, `zhinst-utils`, NumPy, and the other dependencies declared by the toolkit. Editable mode means that updating the checkout does not require copying source files into the skill.

Verify the environment and the installed toolkit:

```powershell
& $Python -c "import zhinst.toolkit, zhinst.core; print('toolkit environment ready')"
& $Python (Join-Path $Repo 'zurich-mfli\scripts\mfli_toolkit.py') discover
```

### Alternative: standard Python `venv`

If `uv` is unavailable, the equivalent commands are:

```powershell
py -3 -m venv (Join-Path $Root '.venv')
& $Python -m pip install -e $Toolkit
```

The resulting directory and installed packages are the same; only the environment creation tool differs.

## Usage Tutorial

Set these variables once in PowerShell:

```powershell
$Root = 'D:\HS_AFM'
$Repo = Join-Path $Root 'Zurich_Instruments_Skills'
$Python = Join-Path $Root '.venv\Scripts\python.exe'
$Adapter = Join-Path $Repo 'zurich-mfli\scripts\mfli_toolkit.py'
```

### 1. Discover devices

```powershell
& $Python $Adapter discover
```

The JSON result includes the serial, model, Data Server address, API level, interface, and ownership status. Always run discovery before selecting a serial; do not assume a serial is permanent.

### 2. Read status

```powershell
& $Python $Adapter status --device DEV5617
```

Check `version_match`. A false value is a warning for reads and a block for writes by default.

### 3. Read a node

```powershell
& $Python $Adapter read --device DEV5617 --node '/DEV5617/DEMODS/0/RATE'
```

Node paths use the LabOne absolute form `/DEVICE/...`. The command returns the normalized path, value, server, and version information.

### 4. Read a demodulator sample

```powershell
& $Python $Adapter sample --device DEV5617 --demod 0
```

The sample contains timestamp, `x`, `y`, frequency, phase, auxiliary inputs, trigger, and DIO fields. The values remain arrays because the LabOne API preserves sample shape.

### 5. Inspect node metadata with the compatibility adapter

```powershell
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  (Join-Path $Repo 'zurich-mfli\scripts\mfli.ps1') `
  list -Device DEV5617 -Node '/DEV5617/DEMODS/0/*'
```

This adapter is useful when the installed LabOne .NET API is available but the Python environment is not. It returns node descriptions, types, units, and read/write properties.

### 6. Write a node only after confirmation

Do not run this example blindly. First show the exact device, node, old value, and proposed value to the user, then obtain explicit confirmation in the current conversation.

```powershell
& $Python $Adapter write `
  --device DEV5617 `
  --node '/DEV5617/DEMODS/0/RATE' `
  --value 1000 `
  --allow-write `
  --confirm-device DEV5617
```

If client and server versions differ, add `--allow-version-mismatch` only after the user explicitly accepts that risk. Never use this flow as a substitute for firmware updates, factory reset, calibration, AWG upload, or output-safety procedures.

## Safety Model

Discovery, status, node reads, node listing, and demodulator sampling are read-only. Any write requires:

1. A fresh confirmation in the current conversation.
2. An exact device serial confirmation.
3. An explicit write-enable flag.
4. A readback of the resulting value.

The skill does not implicitly reset devices, calibrate hardware, update firmware, upload AWG programs, enable outputs, or disconnect devices. Wildcard writes are rejected.

## Current Verified Setup

The original test machine discovered MFLI `DEV5617` at `192.168.87.198:8004`. Discovery, status, scalar reads, and demodulator samples succeeded. The instrument Data Server reported `26.01`; the installed official Python core reported `26.04.1.6`, so writes were intentionally blocked by the version guard.

Do not hard-code this serial or address in automation. Run discovery on each new machine or after changing the LabOne connection.

## Troubleshooting

- **No device:** verify USB/RNDIS or Ethernet, LabOne services, Web UI visibility, and firewall access to port `8004`.
- **Device in use:** use the discovery-reported Data Server and do not silently reconnect the device elsewhere.
- **Not found on `127.0.0.1:8004`:** the local Data Server may not own the instrument; use the discovery-reported address.
- **Version mismatch:** update LabOne/API to a matching release before normal writes.
- **Python import error:** call the `.venv` Python explicitly and reinstall the editable toolkit checkout with `uv pip install --python $Python -e $Toolkit`.

## Attribution

The adapter follows the public Zurich Instruments `zhinst-toolkit` API. The official driver is maintained by Zurich Instruments and is available under its own license at <https://github.com/zhinst/zhinst-toolkit>. This repository contains the Codex skill and integration guidance, not a replacement for the official driver or LabOne documentation.
