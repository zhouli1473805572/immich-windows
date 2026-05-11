# Machine Learning

<p>
  <a href="#中文">中文</a>
  ·
  <a href="#english">English</a>
</p>

<details open id="中文">
<summary><strong>中文</strong></summary>

## 说明

这里是 Immich Machine Learning 服务。Windows 原生运行时优先使用内置虚拟环境：

```text
machine-learning\.venv\Scripts\python.exe
```

## 服务信息

| 项目 | 值 |
| --- | --- |
| 地址 | `127.0.0.1:3003` |
| 模型缓存 | `runtime\models` |
| 日志 | `runtime\logs` |

## 关键环境变量

```text
IMMICH_HOST=127.0.0.1
IMMICH_PORT=3003
PORT=3003
MACHINE_LEARNING_HOST=127.0.0.1
MACHINE_LEARNING_PORT=3003
MACHINE_LEARNING_CACHE_FOLDER=runtime\models
MACHINE_LEARNING_WORKERS=1
```

如果 ML 日志显示它尝试绑定 `2283`，说明使用了旧的启动环境。请重新编译并运行最新的 `build\ImmichManager.exe`。

第三方模型和依赖有各自的许可证。人脸识别模型来自 InsightFace 生态，使用前请确认目标场景符合其许可要求。

</details>

<details id="english">
<summary><strong>English</strong></summary>

## About

This folder contains the Immich Machine Learning service. The Windows-native runtime prefers the bundled virtual environment:

```text
machine-learning\.venv\Scripts\python.exe
```

## Service Info

| Item | Value |
| --- | --- |
| Address | `127.0.0.1:3003` |
| Model cache | `runtime\models` |
| Logs | `runtime\logs` |

## Key Environment Variables

```text
IMMICH_HOST=127.0.0.1
IMMICH_PORT=3003
PORT=3003
MACHINE_LEARNING_HOST=127.0.0.1
MACHINE_LEARNING_PORT=3003
MACHINE_LEARNING_CACHE_FOLDER=runtime\models
MACHINE_LEARNING_WORKERS=1
```

If ML logs show that it is trying to bind to `2283`, an old launch environment is being used. Rebuild and run the latest `build\ImmichManager.exe`.

Third-party models and dependencies have their own licenses. Facial recognition models come from the InsightFace ecosystem; verify license compatibility for your use case.

</details>
