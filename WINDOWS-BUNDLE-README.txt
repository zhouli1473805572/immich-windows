Immich Windows 原生整合包 / Immich Windows Native Bundle
========================================================

中文
----
启动：
  1. 解压整个目录。
  2. 运行 build\ImmichManager.exe。
  3. 点击“启动全部”。
  4. 打开 http://127.0.0.1:2283。

打包：
  双击 package-clean-bundle.cmd
  或运行：
  powershell -ExecutionPolicy Bypass -File .\scripts\windows\package-clean-bundle.ps1

打包脚本默认清空本机运行数据，保证 zip 是全新的：
  runtime\data\postgres
  runtime\data\redis
  runtime\logs
  upload
  runtime\hf-home
  .cache\immich_ml
  runtime\immich-windows.env

保留的运行时：
  runtime\postgres
  runtime\redis
  runtime\node
  runtime\python
  runtime\tools
  runtime\models
  machine-learning\.venv

常用排查：
  日志：runtime\logs
  模型：runtime\models
  上传：upload
  PostgreSQL：127.0.0.1:54329
  Redis：127.0.0.1:63790
  Machine Learning：127.0.0.1:3003
  Server/Web：127.0.0.1:2283

English
-------
Start:
  1. Extract the whole directory.
  2. Run build\ImmichManager.exe.
  3. Click Start All.
  4. Open http://127.0.0.1:2283.

Package:
  Double-click package-clean-bundle.cmd
  or run:
  powershell -ExecutionPolicy Bypass -File .\scripts\windows\package-clean-bundle.ps1

The packaging script clears local runtime data by default so the zip starts fresh:
  runtime\data\postgres
  runtime\data\redis
  runtime\logs
  upload
  runtime\hf-home
  .cache\immich_ml
  runtime\immich-windows.env

Kept runtime files:
  runtime\postgres
  runtime\redis
  runtime\node
  runtime\python
  runtime\tools
  runtime\models
  machine-learning\.venv

Troubleshooting:
  Logs: runtime\logs
  Models: runtime\models
  Uploads: upload
  PostgreSQL: 127.0.0.1:54329
  Redis: 127.0.0.1:63790
  Machine Learning: 127.0.0.1:3003
  Server/Web: 127.0.0.1:2283
