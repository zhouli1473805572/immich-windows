# Web UI / Web 页面

## 中文

`web` 是 Immich 的 Svelte Web 页面源码。Windows 整合包运行时使用构建产物：

```text
build\www
```

如果 Web 页面报错或 `build\www\index.html` 缺失，重新构建：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build-web.ps1
```

构建脚本使用内置 Node.js 和 pnpm：

```text
runtime\node\node-v22.20.0-win-x64\node.exe
runtime\tools\pnpm\package\bin\pnpm.cjs
```

## English

`web` contains the Svelte Web UI source for Immich. The Windows bundle serves the built files from:

```text
build\www
```

If the Web UI fails or `build\www\index.html` is missing, rebuild it:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build-web.ps1
```

The build script uses bundled Node.js and pnpm:

```text
runtime\node\node-v22.20.0-win-x64\node.exe
runtime\tools\pnpm\package\bin\pnpm.cjs
```
