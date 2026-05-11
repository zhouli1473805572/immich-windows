# Immich Windows Native

<p align="center">
  <strong>轻量 Windows 原生启动版</strong><br>
  Immich Server + Web + Machine Learning + PostgreSQL + Redis
</p>

<p align="center">
  <a href="#中文">中文</a>
  ·
  <a href="#english">English</a>
</p>

<details open id="中文">
<summary><strong>中文启动说明</strong></summary>

## 这是什么

这是为 Windows 准备的 Immich 原生运行目录。它保留服务端、网页端和机器学习服务，并内置运行所需的 PostgreSQL、Redis、Node.js、Python、模型和 geodata。

你不需要安装 Docker，也不需要安装数据库或 Redis。正常情况下，只要下载、解压、打开管理器、点击启动即可。

## 第一次使用

### 1. 下载

下载完整的 ****项目代码。

请确认下载的是完整目录压缩包，而不是单独的 `ImmichManager.exe`。管理器只是启动入口，真正运行还需要旁边的 `runtime`、`server`、`web`、`machine-learning` 等目录。

### 2. 放到一个简单路径

推荐放到：

```text
C:\ImmichWindows
```

也可以放到桌面，但不要放到需要管理员权限的目录，例如：

```text
C:\Program Files
C:\Windows
```

路径太深、同步盘、网盘目录也不推荐，后面排查问题会麻烦一些。

### 3. 解压整个压缩包

右键 `immich-window-bundle.zip`，选择“全部解压”。

解压后应该能看到这些内容：

```text
build\ImmichManager.exe
runtime\
server\
web\
machine-learning\
scripts\
upload\
```

如果只看到一个 exe，说明解压或复制方式不对，需要重新解压完整目录。

### 4. 启动管理器

双击：

```text
build\ImmichManager.exe
```

如果 Windows 弹出安全提示，选择允许运行。首次启动时 Windows Defender 可能会扫描 Node、Python 和模型文件，等待一会儿是正常的。

### 5. 启动全部服务

在管理器窗口里点击：

```text
启动全部
```

管理器会依次启动：

```text
PostgreSQL
Redis
Machine Learning
Immich Server
```

第一次启动会初始化数据库，耗时会比平时长。等状态变成运行中后，再打开网页。

### 6. 打开 Immich 网页

在浏览器打开：

```text
http://127.0.0.1:2283
```

第一次进入会要求创建管理员账号。创建完成后，就可以上传照片，或者在 Immich 的管理页面里添加外部图库。

## 常用位置


| 用途            | 位置                         |
| --------------- | ---------------------------- |
| 管理器          | `build\ImmichManager.exe`    |
| 网页地址        | `http://127.0.0.1:2283`      |
| 日志            | `runtime\logs`               |
| 上传目录        | `upload`                     |
| PostgreSQL 数据 | `runtime\data\postgres`      |
| Redis 数据      | `runtime\data\redis`         |
| 机器学习模型    | `runtime\models`             |
| 可选配置        | `runtime\immich-windows.env` |

## 默认端口


| 服务                | 地址              |
| ------------------- | ----------------- |
| Immich Server / Web | `127.0.0.1:2283`  |
| Machine Learning    | `127.0.0.1:3003`  |
| PostgreSQL          | `127.0.0.1:54329` |
| Redis               | `127.0.0.1:63790` |

## 修改配置

如果你需要改端口、上传目录或模型目录，复制这个文件：

```text
scripts\windows\immich-windows.example.env
```

到：

```text
runtime\immich-windows.env
```

然后按需修改。常用配置如下：

```text
IMMICH_HOST=127.0.0.1
IMMICH_PORT=2283
IMMICH_MEDIA_LOCATION=C:\ImmichWindows\upload
IMMICH_POSTGRES_PORT=54329
IMMICH_REDIS_PORT=63790
IMMICH_MACHINE_LEARNING_URL=http://127.0.0.1:3003
MACHINE_LEARNING_CACHE_FOLDER=C:\ImmichWindows\runtime\models
MACHINE_LEARNING_WORKERS=1
```

修改后，请在管理器里停止全部服务，再重新启动。

## 新手排查

### 管理器打不开

确认你打开的是：

```text
build\ImmichManager.exe
```

并确认整个目录都在，不是只复制了 exe。

### 网页打不开

先看管理器里 `Immich Server` 是否显示运行中。然后检查日志：

```text
runtime\logs
```

如果提示 `EADDRINUSE`，说明端口被占用。可以关闭占用端口的软件，或修改 `runtime\immich-windows.env` 里的端口。

### 数据库启动失败

查看：

```text
runtime\logs\postgres.log
```

常见原因是端口 `54329` 被占用，或目录权限不足。建议把项目放到 `C:\ImmichWindows` 这类普通目录。

### Redis 启动失败

查看：

```text
runtime\logs\redis.log
```

常见原因是端口 `63790` 被占用。

### 机器学习服务启动慢

第一次启动会加载 Python 环境和模型。请等待管理器状态更新。模型目录在：

```text
runtime\models
```

### 外部图库扫描不到

先确认 Windows 当前用户能直接访问该目录。建议在 Immich 里填写类似这样的路径：

```text
D:\照片
D:\杂物堆\发票
```

如果路径里有特殊权限、网络盘或同步盘，先用普通本地目录测试。

</details>

<details id="english">
<summary><strong>English Start Guide</strong></summary>

## What This Is

This is a Windows-native Immich runtime directory. It keeps the server, web UI, and machine-learning service, and includes PostgreSQL, Redis, Node.js, Python, models, and geodata.

You do not need Docker, and you do not need to install PostgreSQL or Redis manually. In the normal case, download, extract, open the manager, and click start.

## First Run

### 1. Download

Download the complete `immich-window-bundle.zip`.

Make sure you downloaded the whole directory archive, not only `ImmichManager.exe`. The manager is only the launcher; the runtime also needs the nearby `runtime`, `server`, `web`, `machine-learning`, and other folders.

### 2. Put It in a Simple Path

Recommended path:

```text
C:\ImmichWindows
```

Avoid protected folders such as:

```text
C:\Program Files
C:\Windows
```

Very deep paths, cloud-sync folders, and network drives are also not recommended.

### 3. Extract the Whole Archive

Right-click `immich-window-bundle.zip` and choose "Extract All".

After extraction, you should see:

```text
build\ImmichManager.exe
runtime\
server\
web\
machine-learning\
scripts\
upload\
```

If you only see one exe file, the archive was not extracted correctly.

### 4. Open the Manager

Double-click:

```text
build\ImmichManager.exe
```

If Windows shows a security prompt, allow it to run. On the first launch, Windows Defender may scan Node, Python, and model files, so a short delay is normal.

### 5. Start All Services

In the manager window, click:

```text
Start All
```

The manager starts:

```text
PostgreSQL
Redis
Machine Learning
Immich Server
```

The first launch initializes the database and can take longer than usual. Wait until the services are running before opening the web page.

### 6. Open Immich

Open this URL in your browser:

```text
http://127.0.0.1:2283
```

On the first visit, create the administrator account. After that, you can upload photos or add an external library from the Immich administration pages.

## Important Paths


| Purpose         | Path                         |
| --------------- | ---------------------------- |
| Manager         | `build\ImmichManager.exe`    |
| Web URL         | `http://127.0.0.1:2283`      |
| Logs            | `runtime\logs`               |
| Uploads         | `upload`                     |
| PostgreSQL data | `runtime\data\postgres`      |
| Redis data      | `runtime\data\redis`         |
| ML models       | `runtime\models`             |
| Optional config | `runtime\immich-windows.env` |

## Default Ports


| Service             | Address           |
| ------------------- | ----------------- |
| Immich Server / Web | `127.0.0.1:2283`  |
| Machine Learning    | `127.0.0.1:3003`  |
| PostgreSQL          | `127.0.0.1:54329` |
| Redis               | `127.0.0.1:63790` |

## Configuration

To change ports, upload location, or model location, copy:

```text
scripts\windows\immich-windows.example.env
```

to:

```text
runtime\immich-windows.env
```

Common settings:

```text
IMMICH_HOST=127.0.0.1
IMMICH_PORT=2283
IMMICH_MEDIA_LOCATION=C:\ImmichWindows\upload
IMMICH_POSTGRES_PORT=54329
IMMICH_REDIS_PORT=63790
IMMICH_MACHINE_LEARNING_URL=http://127.0.0.1:3003
MACHINE_LEARNING_CACHE_FOLDER=C:\ImmichWindows\runtime\models
MACHINE_LEARNING_WORKERS=1
```

After editing the file, stop all services in the manager and start them again.

## Basic Troubleshooting

### Manager Does Not Open

Make sure you are opening:

```text
build\ImmichManager.exe
```

Also make sure the whole extracted directory is present.

### Web Page Does Not Open

Check whether `Immich Server` is running in the manager. Then inspect:

```text
runtime\logs
```

If the log says `EADDRINUSE`, the port is already in use. Close the other program or change the port in `runtime\immich-windows.env`.

### Database Fails to Start

Check:

```text
runtime\logs\postgres.log
```

Common causes are port `54329` being used by another process, or insufficient folder permissions.

### Redis Fails to Start

Check:

```text
runtime\logs\redis.log
```

The usual cause is port `63790` already being used.

### Machine Learning Starts Slowly

The first start loads the Python environment and models. Wait for the manager status to update. Models are stored in:

```text
runtime\models
```

### External Library Finds No Files

Make sure the current Windows user can access the folder directly. Example paths:

```text
D:\Photos
D:\Invoices
```

For permission-sensitive folders, network drives, or cloud-sync folders, test with a simple local folder first.

</details>
