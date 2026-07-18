# Zurich Instruments Skills / Zurich Instruments 技能

This repository contains a Codex skill for safely connecting to and operating Zurich Instruments MFLI lock-in amplifiers through LabOne.

本仓库包含一个 Codex skill，用于通过 LabOne 安全连接和操作 Zurich Instruments MFLI 锁相放大器。

## What Is Included / 仓库内容

### English

- `zurich-mfli/`: the skill definition, safety workflow, references, and two adapters.
- `zurich-mfli/scripts/mfli_toolkit.py`: preferred adapter using the official `zhinst-toolkit` Python API.
- `zurich-mfli/scripts/mfli.ps1`: Windows compatibility adapter using the LabOne .NET API already installed with LabOne.
- No virtual environment, instrument data, credentials, or third-party source tree is committed.

### 中文

- `zurich-mfli/`：skill 定义、安全工作流、参考资料和两个适配器。
- `zurich-mfli/scripts/mfli_toolkit.py`：优先使用的官方 `zhinst-toolkit` Python API 适配器。
- `zurich-mfli/scripts/mfli.ps1`：Windows 兼容适配器，使用 LabOne 安装的 .NET API。
- 仓库不提交虚拟环境、仪器数据、凭据或第三方源码。

## Safety Model / 安全模型

### English

The skill is read-only by default. Discovery, status, node reads, node listing, and demodulator sampling do not change instrument settings. Any node write requires all of the following:

1. Show the exact device, node, old value, and proposed value to the user.
2. Receive explicit confirmation in the current conversation.
3. Pass the device serial confirmation and the write-enable flag to the adapter.
4. Read the node back and report the resulting value.

Writes are blocked when the client and Data Server versions differ unless the user explicitly accepts that additional risk. Factory reset, calibration, firmware update, AWG upload, output enabling, and device disconnect are not implicit operations.

### 中文

本 skill 默认只读。设备发现、状态查询、节点读取、节点列表和解调采样不会修改仪器设置。任何节点写入都必须满足以下条件：

1. 向用户展示准确的设备、节点、旧值和拟写入值。
2. 在当前对话中获得明确确认。
3. 向适配器传入设备序列号确认参数和写入开关。
4. 读回节点并报告最终值。

客户端和 Data Server 版本不一致时默认禁止写入，除非用户明确接受额外风险。恢复出厂设置、校准、固件升级、AWG 上传、开启输出和断开设备都不会被隐式执行。

## Requirements / 环境要求

### English

- Windows with PowerShell.
- LabOne installed and able to see the MFLI in its Web UI.
- Python 3.10 or newer for the preferred adapter.
- Network access to the Data Server, normally port `8004`.
- For normal writes, keep the client Python API and the instrument Data Server on the same LabOne release.

The official toolkit requires LabOne 25.04 or newer. The compatibility adapter can use older installed .NET APIs for read-only work, but version mismatches should be resolved before writes.

### 中文

- Windows 和 PowerShell。
- 已安装 LabOne，并能在 LabOne Web UI 中看到 MFLI。
- 优先适配器需要 Python 3.10 或更新版本。
- 能访问 Data Server，通常是 `8004` 端口。
- 正常写入前，应让 Python API 客户端和仪器 Data Server 使用同一个 LabOne 版本。

官方 toolkit 要求 LabOne 25.04 或更新版本。兼容适配器可以使用较旧的 .NET API 进行只读操作，但写入前应解决版本不匹配。

## Installation / 安装

### English

The commands below use `D:\HS_AFM` as the installation root. Replace it with another directory if needed.

```powershell
$Root = 'D:\HS_AFM'
$Repo = Join-Path $Root 'Zurich_Instruments_Skills'

git clone https://github.com/RRGGZZ/Zurich_Instruments_Skills.git $Repo

# Clone the official driver separately; it is intentionally not vendored here.
git clone https://github.com/zhinst/zhinst-toolkit.git (Join-Path $Root 'zhinst-toolkit')

py -3 -m venv (Join-Path $Root '.venv')
& (Join-Path $Root '.venv\Scripts\python.exe') -m pip install -e (Join-Path $Root 'zhinst-toolkit')
```

Verify the skill structure and discover the instrument:

```powershell
& (Join-Path $Root '.venv\Scripts\python.exe') `
  (Join-Path $Repo 'zurich-mfli\scripts\mfli_toolkit.py') discover
```

### 中文

下面的命令使用 `D:\HS_AFM` 作为安装根目录。如使用其他目录，请替换该变量。

```powershell
$Root = 'D:\HS_AFM'
$Repo = Join-Path $Root 'Zurich_Instruments_Skills'

git clone https://github.com/RRGGZZ/Zurich_Instruments_Skills.git $Repo

# 单独克隆官方驱动；本仓库不会把第三方源码打包进来。
git clone https://github.com/zhinst/zhinst-toolkit.git (Join-Path $Root 'zhinst-toolkit')

py -3 -m venv (Join-Path $Root '.venv')
& (Join-Path $Root '.venv\Scripts\python.exe') -m pip install -e (Join-Path $Root 'zhinst-toolkit')
```

验证 skill 结构并发现仪器：

```powershell
& (Join-Path $Root '.venv\Scripts\python.exe') `
  (Join-Path $Repo 'zurich-mfli\scripts\mfli_toolkit.py') discover
```

## Usage Tutorial / 使用教程

### 1. Discover devices / 发现设备

```powershell
& 'D:\HS_AFM\.venv\Scripts\python.exe' `
  'D:\HS_AFM\Zurich_Instruments_Skills\zurich-mfli\scripts\mfli_toolkit.py' discover
```

The result includes the serial, model, Data Server address, API level, interface, and ownership status. Always use discovery before selecting a serial; do not assume the serial is permanent.

结果包含序列号、型号、Data Server 地址、API level、接口和占用状态。每次操作前都应先发现设备，不要假设序列号永久不变。

### 2. Read status / 读取状态

```powershell
& 'D:\HS_AFM\.venv\Scripts\python.exe' `
  'D:\HS_AFM\Zurich_Instruments_Skills\zurich-mfli\scripts\mfli_toolkit.py' `
  status --device DEV5617
```

Check `version_match`. A false value is a warning for reads and a block for writes by default.

检查 `version_match`。它为 `false` 时只读操作仍可作为诊断使用，但写入默认会被阻止。

### 3. Read a node / 读取节点

```powershell
& 'D:\HS_AFM\.venv\Scripts\python.exe' `
  'D:\HS_AFM\Zurich_Instruments_Skills\zurich-mfli\scripts\mfli_toolkit.py' `
  read --device DEV5617 --node '/DEV5617/DEMODS/0/RATE'
```

Node paths use the LabOne absolute form `/DEVICE/...`. The command returns JSON with the normalized node path, value, server, and version information.

节点路径使用 LabOne 绝对格式 `/DEVICE/...`。命令返回包含标准化节点路径、节点值、服务器和版本信息的 JSON。

### 4. Read a demodulator sample / 读取解调采样

```powershell
& 'D:\HS_AFM\.venv\Scripts\python.exe' `
  'D:\HS_AFM\Zurich_Instruments_Skills\zurich-mfli\scripts\mfli_toolkit.py' `
  sample --device DEV5617 --demod 0
```

The sample contains timestamp, `x`, `y`, frequency, phase, auxiliary inputs, trigger, and DIO fields. Compute magnitude and phase from `x` and `y` when needed; the returned values are arrays because the LabOne API preserves sample shape.

采样结果包含时间戳、`x`、`y`、频率、相位、辅助输入、触发和 DIO 字段。需要时可根据 `x` 和 `y` 计算幅值与相位；返回值保留为数组，因为 LabOne API 会保留采样形状。

### 5. List metadata with the compatibility adapter / 使用兼容适配器查看节点元数据

```powershell
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  'D:\HS_AFM\Zurich_Instruments_Skills\zurich-mfli\scripts\mfli.ps1' `
  list -Device DEV5617 -Node '/DEV5617/DEMODS/0/*'
```

This is useful when you need the node description, type, unit, and read/write properties. It uses the LabOne .NET API installed on Windows and does not require Python.

当需要查看节点说明、类型、单位以及读写属性时，可以使用此命令。它使用 Windows 上安装的 LabOne .NET API，不需要 Python。

### 6. Write a node only after confirmation / 确认后写入节点

Do not run this example blindly. First show the old value and proposed value to the user and obtain explicit confirmation in the current conversation.

不要直接盲目运行此示例。必须先向用户展示旧值和拟写入值，并在当前对话中获得明确确认。

```powershell
& 'D:\HS_AFM\.venv\Scripts\python.exe' `
  'D:\HS_AFM\Zurich_Instruments_Skills\zurich-mfli\scripts\mfli_toolkit.py' `
  write --device DEV5617 --node '/DEV5617/DEMODS/0/RATE' --value 1000 `
  --allow-write --confirm-device DEV5617
```

If the client and server versions differ, add `--allow-version-mismatch` only after explicitly accepting that risk. Never use this flow as a substitute for a requested firmware update, factory reset, calibration, or output-safety procedure.

客户端和服务器版本不一致时，只有在明确接受风险后才能添加 `--allow-version-mismatch`。不要把此流程当作固件升级、恢复出厂、校准或输出安全操作的替代方案。

## Current Verified Setup / 当前已验证环境

The original test machine discovered MFLI `DEV5617` at `192.168.87.198:8004`. The instrument Data Server reported `26.01`; the installed official Python core reported `26.04.1.6`. Discovery, status, scalar reads, and demod samples succeeded. Writes remained intentionally blocked by the skill's version guard.

原测试机器发现的 MFLI 为 `DEV5617`，地址是 `192.168.87.198:8004`。仪器 Data Server 为 `26.01`，官方 Python core 为 `26.04.1.6`。设备发现、状态读取、标量读取和解调采样均成功；由于版本保护，写入被有意禁止。

Do not hard-code this serial or address in automation. Run discovery on every new machine or after changing the LabOne connection.

不要在自动化程序中硬编码这个序列号或地址。更换机器或 LabOne 连接后，应重新执行设备发现。

## Troubleshooting / 故障排查

### English

- No device: verify USB/RNDIS or Ethernet, LabOne services, Web UI visibility, and firewall access to port `8004`.
- Device is in use: use the discovery-reported Data Server and do not silently reconnect it elsewhere.
- Device not found on `127.0.0.1:8004`: the local Data Server may not own the instrument; use the discovery-reported server address.
- Version mismatch: update LabOne/API to a matching release before normal writes.
- Python import error: activate or call the repository's `.venv` explicitly and reinstall the editable toolkit checkout.

### 中文

- 找不到设备：检查 USB/RNDIS 或以太网、LabOne 服务、Web UI 可见性以及防火墙是否允许 `8004` 端口。
- 设备显示被占用：使用 discovery 返回的 Data Server，不要静默地把设备重新连接到其他服务器。
- `127.0.0.1:8004` 找不到设备：本地 Data Server 可能不拥有该仪器，应使用 discovery 返回的服务器地址。
- 版本不匹配：正常写入前升级或调整 LabOne/API 到匹配版本。
- Python 导入错误：明确调用本仓库的 `.venv`，并重新以 editable 模式安装 toolkit checkout。

## Attribution / 归属

The adapter follows the public Zurich Instruments `zhinst-toolkit` API. The official driver is maintained by Zurich Instruments and is available under its own license at https://github.com/zhinst/zhinst-toolkit. This repository contains the Codex skill and integration guidance, not a replacement for the official driver or LabOne documentation.

适配器遵循 Zurich Instruments 公开的 `zhinst-toolkit` API。官方驱动由 Zurich Instruments 维护，并按其自身许可证发布于 https://github.com/zhinst/zhinst-toolkit。本仓库提供 Codex skill 和集成说明，不替代官方驱动或 LabOne 文档。
