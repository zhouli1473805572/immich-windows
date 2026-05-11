# Windows Build and Packaging

<p>
  <a href="#中文">中文</a>
  ·
  <a href="#english">English</a>
</p>

<details open id="中文">
<summary><strong>中文</strong></summary>

## 说明

这里放 Windows 原生运行、构建和打包相关脚本。面向最终用户的启动说明在项目根目录 `README.md`，这里主要给维护者使用。

## 一键打包

从项目根目录双击：

```text
package-clean-bundle.cmd
```

或者运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package-clean-bundle.ps1
```

默认输出：

```text
..\immich-window-bundle.zip
```

## 打包时会做什么

脚本会检查并准备运行时组件、构建网页、编译管理器、预加载模型，然后生成全新的压缩包。

正式生成压缩包前，脚本会清理当前项目里的本机运行数据，避免把你的数据库、上传文件、日志和本机配置带到新包里：

```text
runtime\data\postgres
runtime\data\redis
runtime\logs
upload
runtime\hf-home
.cache\immich_ml
runtime\immich-windows.env
```

这些固定运行组件会保留：

```text
runtime\postgres
runtime\redis
runtime\node
runtime\python
runtime\tools
runtime\models
machine-learning\.venv
build\www
build\ImmichManager.exe
```

## 常用参数

只测试流程，不生成压缩包：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package-clean-bundle.ps1 -NoArchive
```

生成压缩包，但保留当前项目目录里的本机数据和本机配置：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package-clean-bundle.ps1 -KeepLocalData -KeepLocalConfig
```

跳过网页构建：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package-clean-bundle.ps1 -SkipWebBuild
```

跳过模型预加载：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package-clean-bundle.ps1 -SkipModelPreload
```

指定输出位置：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package-clean-bundle.ps1 -OutputZip D:\dist\immich-window-bundle.zip
```

## 相关脚本

| 脚本 | 用途 |
| --- | --- |
| `package-clean-bundle.ps1` | 打包入口，转发参数到主脚本 |
| `package-bundle.ps1` | 完整打包逻辑 |
| `runtime-download.ps1` | 检查并补齐运行时组件 |
| `start-all.ps1` | 启动 PostgreSQL、Redis、ML 和 Server |
| `build-web.ps1` | 构建 Web 页面到 `build\www` |
| `native-env.ps1` | 统一 Windows 原生运行环境 |

</details>

<details id="english">
<summary><strong>English</strong></summary>

## About

This folder contains Windows-native runtime, build, and packaging scripts. The end-user start guide lives in the root `README.md`; this file is mainly for maintainers.

## One-Click Packaging

From the project root, double-click:

```text
package-clean-bundle.cmd
```

Or run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package-clean-bundle.ps1
```

Default output:

```text
..\immich-window-bundle.zip
```

## What the Packaging Script Does

The script checks and prepares runtime components, builds the web UI, compiles the manager, preloads models, and creates a fresh archive.

Before creating the archive, it cleans local runtime data from the current workspace so your database, uploads, logs, and local config are not included:

```text
runtime\data\postgres
runtime\data\redis
runtime\logs
upload
runtime\hf-home
.cache\immich_ml
runtime\immich-windows.env
```

These fixed runtime components are kept:

```text
runtime\postgres
runtime\redis
runtime\node
runtime\python
runtime\tools
runtime\models
machine-learning\.venv
build\www
build\ImmichManager.exe
```

## Common Options

Test the flow without creating an archive:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package-clean-bundle.ps1 -NoArchive
```

Create an archive while keeping local data and local config in the current workspace:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package-clean-bundle.ps1 -KeepLocalData -KeepLocalConfig
```

Skip the web build:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package-clean-bundle.ps1 -SkipWebBuild
```

Skip model preload:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package-clean-bundle.ps1 -SkipModelPreload
```

Set an output path:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package-clean-bundle.ps1 -OutputZip D:\dist\immich-window-bundle.zip
```

## Related Scripts

| Script | Purpose |
| --- | --- |
| `package-clean-bundle.ps1` | Packaging entry point, forwards options to the main script |
| `package-bundle.ps1` | Full packaging logic |
| `runtime-download.ps1` | Checks and fills missing runtime components |
| `start-all.ps1` | Starts PostgreSQL, Redis, ML, and Server |
| `build-web.ps1` | Builds the Web UI into `build\www` |
| `native-env.ps1` | Shared Windows-native runtime environment |

</details>
