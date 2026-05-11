# Runtime Directory

<p>
  <a href="#中文">中文</a>
  ·
  <a href="#english">English</a>
</p>

<details open id="中文">
<summary><strong>中文</strong></summary>

## 说明

`runtime` 存放 Windows 原生运行所需的二进制文件、模型、本机数据和日志。

## 固定运行时

这些目录是运行服务需要的组件：

```text
runtime\postgres
runtime\redis
runtime\node
runtime\python
runtime\tools
runtime\models
```

## 本机运行数据

这些目录会在启动后生成或变化：

```text
runtime\data\postgres
runtime\data\redis
runtime\logs
runtime\hf-home
```

不要手动删除正在运行中的数据库目录。需要清理数据时，请先在管理器里停止全部服务。

## 可选配置

```text
runtime\immich-windows.env
```

该文件用于覆盖端口、上传目录、模型目录等。修改后需要重启服务。

## 默认端口

| 服务 | 地址 |
| --- | --- |
| PostgreSQL | `127.0.0.1:54329` |
| Redis | `127.0.0.1:63790` |
| Machine Learning | `127.0.0.1:3003` |
| Immich Server / Web | `127.0.0.1:2283` |

</details>

<details id="english">
<summary><strong>English</strong></summary>

## About

`runtime` stores binaries, models, local data, and logs required by the Windows-native runtime.

## Fixed Runtime Files

These directories are required to run the services:

```text
runtime\postgres
runtime\redis
runtime\node
runtime\python
runtime\tools
runtime\models
```

## Local Runtime Data

These directories are created or changed while the app is running:

```text
runtime\data\postgres
runtime\data\redis
runtime\logs
runtime\hf-home
```

Do not manually delete the database directory while services are running. Stop all services in the manager before cleaning data.

## Optional Config

```text
runtime\immich-windows.env
```

This file can override ports, upload paths, model paths, and related settings. Restart services after editing it.

## Default Ports

| Service | Address |
| --- | --- |
| PostgreSQL | `127.0.0.1:54329` |
| Redis | `127.0.0.1:63790` |
| Machine Learning | `127.0.0.1:3003` |
| Immich Server / Web | `127.0.0.1:2283` |

</details>
