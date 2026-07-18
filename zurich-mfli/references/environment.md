# Local Environment

## Paths

- Official toolkit checkout: `D:\HS_AFM\zhinst-toolkit`
- Toolkit virtual environment: `D:\HS_AFM\.venv`
- Skill: `D:\HS_AFM\zurich-mfli`
- LabOne .NET API: `C:\Program Files\Zurich Instruments\LabOne\API\DotNET\ziDotNET-win64.dll`
- Installed programming manual: `C:\Program Files\Zurich Instruments\LabOne\Documentation\pdf\LabOneProgrammingManual.pdf`
- Installed MFLI manual: `C:\Program Files\Zurich Instruments\LabOne\Documentation\pdf\ziMFLI_UserManual.pdf`

## Verified Instrument

The initial read-only check on 2026-07-18 discovered `DEV5617` as an MFLI at `192.168.87.198:8004`, API level 6. Do not assume this serial or address is permanent; always run discovery.

The installed .NET API reported version 21.08 while the instrument Data Server reported 26.01. Read-only status and node queries worked, but writes must remain blocked until versions match or the user explicitly accepts the mismatch risk.

## Backend Selection

Use `scripts/mfli_toolkit.py` with `D:\HS_AFM\.venv` for the preferred modern API. The environment installs the editable checkout plus `zhinst-core 26.4.1.6`, `zhinst-utils 0.7.2`, and the toolkit dependencies.

Use `scripts/mfli.ps1` for compatibility with the installed LabOne .NET API. It does not require Python packages.

Use the official `zhinst-toolkit` checkout as reference code or for a future Python environment. A source checkout alone does not install `zhinst-core`, `zhinst-toolkit`, or their dependencies. Inspect its `pyproject.toml` before creating an environment, and keep the Python API version aligned with the Data Server.

## Troubleshooting

- No devices: verify USB/RNDIS or Ethernet, LabOne services, and Web Server access.
- Device in use: prefer the discovery-reported server address. Do not reconnect it to another Data Server without approval.
- Device not found after connecting to `127.0.0.1:8004`: the local Data Server may not own the device. Query the discovery-reported server instead.
- Version mismatch: update LabOne/API to match the Data Server before normal writes.
