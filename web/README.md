# Web UI

<p>
  <a href="#中文">中文</a>
  ·
  <a href="#english">English</a>
</p>

<details open id="中文">
<summary><strong>中文</strong></summary>

## 说明

`web` 是 Immich 的 Svelte Web 页面源码。Windows 原生运行时实际服务的是构建结果：

```text
build\www
```

## 重新构建网页

如果网页报错，或 `build\www\index.html` 缺失，从项目根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build-web.ps1
```

构建脚本会使用内置 Node.js 和 pnpm：

```text
runtime\node\node-v22.20.0-win-x64\node.exe
runtime\tools\pnpm\package\bin\pnpm.cjs
```

</details>

<details id="english">
<summary><strong>English</strong></summary>

## About

`web` contains the Svelte Web UI source for Immich. The Windows-native runtime serves the built files from:

```text
build\www
```

## Rebuild the Web UI

If the Web UI fails or `build\www\index.html` is missing, run this from the project root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build-web.ps1
```

The build script uses bundled Node.js and pnpm:

```text
runtime\node\node-v22.20.0-win-x64\node.exe
runtime\tools\pnpm\package\bin\pnpm.cjs
```

</details>
