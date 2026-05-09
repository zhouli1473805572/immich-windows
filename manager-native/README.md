# Immich Manager / Immich 管理器

## 中文

这是轻量的 Windows Forms 管理器，不使用 Electron，也不内置 Chromium。

编译产物：

```text
build\ImmichManager.exe
```

管理器负责启动、停止和查看日志：

- PostgreSQL + pgvector
- Redis
- Machine Learning
- Immich Server + Web

### 关键路径

- 源码：`manager-native\ImmichManager.cs`
- 可执行文件：`build\ImmichManager.exe`
- 日志：`runtime\logs`
- PostgreSQL 数据：`runtime\data\postgres`
- Redis 数据：`runtime\data\redis`
- 上传目录：`upload`
- 模型目录：`runtime\models`

### 重新编译

```powershell
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:winexe /out:build\ImmichManager.exe /r:System.dll /r:System.Core.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll manager-native\ImmichManager.cs
```

如果编译时报 `ImmichManager.exe` 被占用，请先关闭正在运行的管理器。

## English

This is a lightweight Windows Forms manager. It does not use Electron and does not embed Chromium.

Build output:

```text
build\ImmichManager.exe
```

The manager starts, stops, and shows logs for:

- PostgreSQL + pgvector
- Redis
- Machine Learning
- Immich Server + Web

### Key Paths

- Source: `manager-native\ImmichManager.cs`
- Executable: `build\ImmichManager.exe`
- Logs: `runtime\logs`
- PostgreSQL data: `runtime\data\postgres`
- Redis data: `runtime\data\redis`
- Uploads: `upload`
- Models: `runtime\models`

### Rebuild

```powershell
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:winexe /out:build\ImmichManager.exe /r:System.dll /r:System.Core.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll manager-native\ImmichManager.cs
```

If the compiler says `ImmichManager.exe` is in use, close the running manager first.
