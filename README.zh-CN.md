# Zurich Instruments 技能

[English](README.md)

本仓库提供一个 Codex skill，用于通过 LabOne 安全发现、检查、读取、采样以及在明确确认后控制 Zurich Instruments MFLI 锁相放大器。

## 仓库内容

- [`zurich-mfli/`](zurich-mfli/)：skill 定义、安全工作流、参考资料和适配器。
- [`mfli_toolkit.py`](zurich-mfli/scripts/mfli_toolkit.py)：优先使用官方 `zhinst-toolkit` Python API 的适配器。
- [`mfli.ps1`](zurich-mfli/scripts/mfli.ps1)：使用 LabOne .NET API 的 Windows 兼容适配器。
- 仓库不提交虚拟环境、仪器数据、凭据或第三方源码。

## 环境要求

- Windows 和 PowerShell。
- 已安装 LabOne，并能在 LabOne Web UI 中看到 MFLI。
- Python 3.10 或更新版本。
- 推荐使用 [`uv`](https://docs.astral.sh/uv/) 创建和维护虚拟环境。
- 能访问 Data Server，通常是 `8004` 端口。

官方 toolkit 要求 LabOne 25.04 或更新版本。正常写入前，应让 Python API 和仪器 Data Server 使用同一个 LabOne 版本。

## 为什么必须创建 `.venv`

优先适配器会导入 `zhinst.toolkit`、`zhinst.core` 及其依赖，因此必须安装在隔离的 Python 环境中。推荐目录结构如下：

```text
D:\HS_AFM\
  .venv\                  # skill 使用的 Python 环境
  zhinst-toolkit\         # Zurich Instruments 官方源码
  Zurich_Instruments_Skills\
    zurich-mfli\          # 本 skill
```

`.venv` 是本机运行状态，已被 `.gitignore` 排除，不应提交到 Git。可以使用其他根目录，但必须相应修改命令中的路径。

## 使用 `uv` 安装（推荐）

下面的 PowerShell 命令使用 `D:\HS_AFM` 作为根目录。如使用其他目录，请替换 `$Root`。

```powershell
$Root = 'D:\HS_AFM'
$Repo = Join-Path $Root 'Zurich_Instruments_Skills'
$Toolkit = Join-Path $Root 'zhinst-toolkit'
$Python = Join-Path $Root '.venv\Scripts\python.exe'

# 如果尚未安装 uv，可以取消下一行注释执行。
# winget install --id=astral-sh.uv -e

git clone https://github.com/RRGGZZ/Zurich_Instruments_Skills.git $Repo
git clone https://github.com/zhinst/zhinst-toolkit.git $Toolkit

uv venv (Join-Path $Root '.venv') --python 3.12
uv pip install --python $Python -e $Toolkit
```

`uv venv` 创建 skill 所需的 `.venv`；`uv pip install --python ... -e` 以 editable 模式安装官方 toolkit，以及它声明的 `zhinst-core`、`zhinst-utils`、NumPy 和其他依赖。editable 模式意味着更新 toolkit checkout 后不需要把源码复制到 skill 中。

验证环境和 toolkit：

```powershell
& $Python -c "import zhinst.toolkit, zhinst.core; print('toolkit environment ready')"
& $Python (Join-Path $Repo 'zurich-mfli\scripts\mfli_toolkit.py') discover
```

### 不使用 `uv` 时的标准 Python `venv`

如果没有 `uv`，可以使用等价的标准命令：

```powershell
py -3 -m venv (Join-Path $Root '.venv')
& $Python -m pip install -e $Toolkit
```

最终目录和已安装的软件包相同，区别只是创建环境所使用的工具不同。

## 使用教程

先在 PowerShell 中设置变量：

```powershell
$Root = 'D:\HS_AFM'
$Repo = Join-Path $Root 'Zurich_Instruments_Skills'
$Python = Join-Path $Root '.venv\Scripts\python.exe'
$Adapter = Join-Path $Repo 'zurich-mfli\scripts\mfli_toolkit.py'
```

### 1. 发现设备

```powershell
& $Python $Adapter discover
```

JSON 结果包含序列号、型号、Data Server 地址、API level、接口和占用状态。每次选择设备前都应重新 discovery，不要假设序列号永久不变。

### 2. 读取状态

```powershell
& $Python $Adapter status --device DEV5617
```

检查 `version_match`。它为 `false` 时，只读操作仍可用于诊断，但写入默认会被阻止。

### 3. 读取节点

```powershell
& $Python $Adapter read --device DEV5617 --node '/DEV5617/DEMODS/0/RATE'
```

节点路径使用 LabOne 绝对格式 `/DEVICE/...`。命令返回标准化节点路径、节点值、服务器和版本信息。

### 4. 读取解调采样

```powershell
& $Python $Adapter sample --device DEV5617 --demod 0
```

采样结果包含时间戳、`x`、`y`、频率、相位、辅助输入、触发和 DIO 字段。返回值保留为数组，因为 LabOne API 会保留采样形状。

### 5. 使用兼容适配器查看节点元数据

```powershell
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  (Join-Path $Repo 'zurich-mfli\scripts\mfli.ps1') `
  list -Device DEV5617 -Node '/DEV5617/DEMODS/0/*'
```

当已安装 LabOne .NET API 但没有 Python 环境时，可以使用此适配器。它会返回节点说明、类型、单位以及读写属性。

### 6. 仅在确认后写入节点

不要盲目运行以下示例。必须先向用户展示准确的设备、节点、旧值和拟写入值，并在当前对话中获得明确确认。

```powershell
& $Python $Adapter write `
  --device DEV5617 `
  --node '/DEV5617/DEMODS/0/RATE' `
  --value 1000 `
  --allow-write `
  --confirm-device DEV5617
```

客户端和服务器版本不一致时，只有在用户明确接受额外风险后才能添加 `--allow-version-mismatch`。不要把此流程当作固件升级、恢复出厂、校准、AWG 上传或输出安全操作的替代方案。

## 安全模型

设备发现、状态查询、节点读取、节点列表和解调采样都是只读操作。任何写入都必须满足：

1. 在当前对话中获得新的明确确认。
2. 传入准确的设备序列号确认。
3. 传入明确的写入开关。
4. 读回最终值。

本 skill 不会隐式恢复设备、校准硬件、升级固件、上传 AWG 程序、开启输出或断开设备，并且会拒绝通配符写入。

## 当前已验证环境

原测试机器发现的 MFLI 为 `DEV5617`，Data Server 地址为 `192.168.87.198:8004`。设备发现、状态读取、标量读取和解调采样均成功。仪器 Data Server 为 `26.01`，官方 Python core 为 `26.04.1.6`，因此版本保护有意禁止写入。

不要在自动化程序中硬编码这个序列号或地址。更换机器或 LabOne 连接后，应重新执行 discovery。

## 故障排查

- **找不到设备：** 检查 USB/RNDIS 或以太网、LabOne 服务、Web UI 可见性以及防火墙是否允许 `8004` 端口。
- **设备被占用：** 使用 discovery 返回的 Data Server，不要静默地把设备重新连接到其他服务器。
- **`127.0.0.1:8004` 找不到设备：** 本地 Data Server 可能不拥有该仪器，应使用 discovery 返回的地址。
- **版本不匹配：** 正常写入前升级或调整 LabOne/API 到匹配版本。
- **Python 导入错误：** 明确调用 `.venv` 中的 Python，并用 `uv pip install --python $Python -e $Toolkit` 重新安装 editable toolkit checkout。

## 归属说明

适配器遵循 Zurich Instruments 公开的 `zhinst-toolkit` API。官方驱动由 Zurich Instruments 维护，并按其自身许可证发布于 <https://github.com/zhinst/zhinst-toolkit>。本仓库提供 Codex skill 和集成说明，不替代官方驱动或 LabOne 文档。
