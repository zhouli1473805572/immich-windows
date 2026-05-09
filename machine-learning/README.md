# Machine Learning / 机器学习服务

## 中文

此目录是 Immich Machine Learning 服务。Windows 整合包优先使用：

```text
machine-learning\.venv\Scripts\python.exe
```

服务端口：

```text
127.0.0.1:3003
```

模型缓存：

```text
runtime\models
```

关键环境变量：

```text
IMMICH_HOST=127.0.0.1
IMMICH_PORT=3003
MACHINE_LEARNING_CACHE_FOLDER=runtime\models
MACHINE_LEARNING_WORKERS=1
```

如果 ML 日志显示尝试绑定 `2283`，说明正在使用旧的 manager 或旧的启动环境。请重新编译并使用最新的 `build\ImmichManager.exe`。

第三方模型和依赖有各自的许可证。人脸识别模型来自 InsightFace 生态，使用前请确认目标场景符合其许可要求。

## English

This directory contains the Immich Machine Learning service. The Windows bundle prefers:

```text
machine-learning\.venv\Scripts\python.exe
```

Service port:

```text
127.0.0.1:3003
```

Model cache:

```text
runtime\models
```

Key environment variables:

```text
IMMICH_HOST=127.0.0.1
IMMICH_PORT=3003
MACHINE_LEARNING_CACHE_FOLDER=runtime\models
MACHINE_LEARNING_WORKERS=1
```

If ML logs show that it is trying to bind to `2283`, an old manager or old launch environment is being used. Rebuild and run the latest `build\ImmichManager.exe`.

Third-party models and dependencies have their own licenses. Facial recognition models come from the InsightFace ecosystem; verify license compatibility for your use case.
