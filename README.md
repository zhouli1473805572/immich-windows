# Immich Windows Native Bundle / Immich Windows 原生整合包

## 中文

这是面向 Windows 的 Immich 原生整合包。它保留 Immich Server、Web 页面、Machine Learning，并内置 PostgreSQL、pgvector、Redis、Node.js、pnpm、Python 3.12、ML 虚拟环境、默认模型、geodata 和 core plugin。

不需要 Docker，不需要 Electron/Chromium。

### 快速启动

推荐方式：

```powershell
build\ImmichManager.exe
```

脚本方式：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\start-all.ps1
```

打开：

```text
http://127.0.0.1:2283
```

### 打包干净版本

正式打包：

双击：

```text
package-clean-bundle.cmd
```

或使用命令：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package-clean-bundle.ps1
```

默认输出：

```text
..\immich-window-bundle.zip
```

打包脚本会停止本项目内的服务，并清空这些本地运行数据，保证压缩包是全新状态：

- `runtime\data\postgres`
- `runtime\data\redis`
- `runtime\logs`
- `upload`
- `runtime\hf-home`
- `.cache\immich_ml`
- `runtime\immich-windows.env`

模型和运行时不会删除：

- `runtime\models`
- `runtime\postgres`
- `runtime\redis`
- `runtime\node`
- `runtime\python`
- `runtime\tools`
- `machine-learning\.venv`

如果只是测试打包脚本，不想清数据：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package-clean-bundle.ps1 -NoArchive
```

如果想保留本机磁盘上的数据、但仍生成不包含数据的干净 zip：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package-clean-bundle.ps1 -KeepLocalData -KeepLocalConfig
```

### 目录和端口


| 项目             | 路径/端口                                  |
| ---------------- | ------------------------------------------ |
| Manager          | `build\ImmichManager.exe`                  |
| Web 静态文件     | `build\www`                                |
| PostgreSQL       | `runtime\postgres`, `127.0.0.1:54329`      |
| PostgreSQL 数据  | `runtime\data\postgres`                    |
| Redis            | `runtime\redis`, `127.0.0.1:63790`         |
| Redis 数据       | `runtime\data\redis`                       |
| Machine Learning | `machine-learning\.venv`, `127.0.0.1:3003` |
| ML 模型          | `runtime\models`                           |
| 上传目录         | `upload`                                   |
| 日志             | `runtime\logs`                             |
| 可选配置         | `runtime\immich-windows.env`               |

### 配置

可复制：

```text
scripts\windows\immich-windows.example.env
```

到：

```text
runtime\immich-windows.env
```

常用配置：

```text
IMMICH_HOST=127.0.0.1
IMMICH_PORT=2283
IMMICH_MEDIA_LOCATION=C:\Immich\upload
IMMICH_POSTGRES_PORT=54329
IMMICH_REDIS_PORT=63790
IMMICH_MACHINE_LEARNING_URL=http://127.0.0.1:3003
MACHINE_LEARNING_CACHE_FOLDER=C:\Immich\runtime\models
MACHINE_LEARNING_WORKERS=1
```

### 排查

- Manager 日志：界面右侧日志栏。
- 服务日志：`runtime\logs`。
- PostgreSQL 无法启动：检查 `runtime\logs\postgres.log` 和端口 `54329` 是否被占用。
- Redis 无法启动：检查 `runtime\logs\redis.log` 和端口 `63790` 是否被占用。
- ML 抢占 2283：请确认使用最新的 `build\ImmichManager.exe`，ML 应使用 `3003`。
- Web 报错：重新运行 `scripts\windows\build-web.ps1`。
- 新机器首次启动慢：Windows Defender 可能会扫描 Node/Python/模型文件。
