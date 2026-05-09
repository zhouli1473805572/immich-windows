# Runtime / 运行时目录

## 中文

`runtime` 存放 Windows 原生整合包需要的二进制、模型、数据和日志。

### 固定运行时

这些目录应随包分发：

```text
runtime\postgres
runtime\redis
runtime\node
runtime\python
runtime\tools
runtime\models
```

### 本机运行数据

这些目录是运行后生成的数据。打包脚本默认会清空它们，保证新包没有本机数据：

```text
runtime\data\postgres
runtime\data\redis
runtime\logs
runtime\hf-home
```

### 可选配置

```text
runtime\immich-windows.env
```

该文件用于覆盖端口、上传目录、模型目录等。正式打包默认不会带入本机配置。

### 端口

- PostgreSQL: `127.0.0.1:54329`
- Redis: `127.0.0.1:63790`
- Machine Learning: `127.0.0.1:3003`
- Immich Server: `127.0.0.1:2283`

## English

`runtime` stores binaries, models, data, and logs required by the Windows-native bundle.

### Fixed Runtime Files

These directories should be shipped with the bundle:

```text
runtime\postgres
runtime\redis
runtime\node
runtime\python
runtime\tools
runtime\models
```

### Local Runtime Data

These directories are created while running. The packaging script clears them by default so a new bundle contains no local data:

```text
runtime\data\postgres
runtime\data\redis
runtime\logs
runtime\hf-home
```

### Optional Config

```text
runtime\immich-windows.env
```

This file can override ports, upload paths, model paths, and related settings. It is not included by default in a clean package.

### Ports

- PostgreSQL: `127.0.0.1:54329`
- Redis: `127.0.0.1:63790`
- Machine Learning: `127.0.0.1:3003`
- Immich Server: `127.0.0.1:2283`
