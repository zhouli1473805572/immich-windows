# Immich Manager

<p>
  <a href="#中文">中文</a>
  ·
  <a href="#english">English</a>
</p>

<details open id="中文">
<summary><strong>中文</strong></summary>

## 说明

这里是轻量 Windows Forms 管理器源码。它不使用 Electron，也不内置 Chromium。

管理器负责启动、停止和查看日志：

```text
PostgreSQL + pgvector
Redis
Machine Learning
Immich Server + Web
```

## 关键路径

| 用途 | 路径 |
| --- | --- |
| 源码 | `manager-native\ImmichManager.cs` |
| 可执行文件 | `build\ImmichManager.exe` |
| 日志 | `runtime\logs` |
| PostgreSQL 数据 | `runtime\data\postgres` |
| Redis 数据 | `runtime\data\redis` |
| 上传目录 | `upload` |
| 模型目录 | `runtime\models` |

## 重新编译

从项目根目录运行：

```powershell
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:winexe /out:build\ImmichManager.exe /r:System.dll /r:System.Core.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll manager-native\ImmichManager.cs
```

如果提示 `ImmichManager.exe` 正在被占用，请先关闭正在运行的管理器。

</details>

<details id="english">
<summary><strong>English</strong></summary>

## About

This folder contains the lightweight Windows Forms manager source. It does not use Electron and does not embed Chromium.

The manager starts, stops, and shows logs for:

```text
PostgreSQL + pgvector
Redis
Machine Learning
Immich Server + Web
```

## Key Paths

| Purpose | Path |
| --- | --- |
| Source | `manager-native\ImmichManager.cs` |
| Executable | `build\ImmichManager.exe` |
| Logs | `runtime\logs` |
| PostgreSQL data | `runtime\data\postgres` |
| Redis data | `runtime\data\redis` |
| Uploads | `upload` |
| Models | `runtime\models` |

## Rebuild

Run this from the project root:

```powershell
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:winexe /out:build\ImmichManager.exe /r:System.dll /r:System.Core.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll manager-native\ImmichManager.cs
```

If the compiler says `ImmichManager.exe` is in use, close the running manager first.

</details>
