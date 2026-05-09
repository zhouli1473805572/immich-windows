param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

function Set-DefaultEnv {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Value
  )

  if (-not [Environment]::GetEnvironmentVariable($Name, "Process")) {
    Set-Item -Path "Env:$Name" -Value $Value
  }
}

$buildDir = Join-Path $RepoRoot "build"
$mediaDir = Join-Path $RepoRoot "upload"
$modelCacheDir = Join-Path $RepoRoot ".cache\immich_ml"
$embeddedModelDir = Join-Path $RepoRoot "runtime\models"
$runtimeDir = Join-Path $RepoRoot "runtime"
$runtimeDataDir = Join-Path $runtimeDir "data"
$postgresDataDir = Join-Path $runtimeDataDir "postgres"
$redisDataDir = Join-Path $runtimeDataDir "redis"

New-Item -ItemType Directory -Force -Path $buildDir, $mediaDir, $modelCacheDir, $embeddedModelDir, $runtimeDataDir, $postgresDataDir, $redisDataDir | Out-Null

Set-DefaultEnv "IMMICH_ENV" "development"
Set-DefaultEnv "IMMICH_HOST" "127.0.0.1"
Set-DefaultEnv "IMMICH_PORT" "2283"
Set-DefaultEnv "IMMICH_BUILD_DATA" $buildDir
Set-DefaultEnv "IMMICH_MEDIA_LOCATION" $mediaDir
Set-DefaultEnv "IMMICH_MACHINE_LEARNING_URL" "http://127.0.0.1:3003"
Set-DefaultEnv "IMMICH_IGNORE_MOUNT_CHECK_ERRORS" "true"

Set-DefaultEnv "IMMICH_RUNTIME_DIR" $runtimeDir
Set-DefaultEnv "IMMICH_POSTGRES_BIN" (Join-Path $runtimeDir "postgres\bin")
Set-DefaultEnv "IMMICH_POSTGRES_DATA" $postgresDataDir
Set-DefaultEnv "IMMICH_REDIS_BIN" (Join-Path $runtimeDir "redis")
Set-DefaultEnv "IMMICH_REDIS_DATA" $redisDataDir
Set-DefaultEnv "IMMICH_POSTGRES_PORT" "54329"
Set-DefaultEnv "IMMICH_REDIS_PORT" "63790"

Set-DefaultEnv "DB_URL" "postgres://postgres:postgres@127.0.0.1:$env:IMMICH_POSTGRES_PORT/immich"
Set-DefaultEnv "DB_VECTOR_EXTENSION" "pgvector"
Set-DefaultEnv "REDIS_HOSTNAME" "127.0.0.1"
Set-DefaultEnv "REDIS_PORT" $env:IMMICH_REDIS_PORT

Set-DefaultEnv "MACHINE_LEARNING_CACHE_FOLDER" $embeddedModelDir
Set-DefaultEnv "MACHINE_LEARNING_WORKERS" "1"
Set-DefaultEnv "HF_HOME" (Join-Path $RepoRoot "runtime\hf-home")

function Get-ImmichNodeDir {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $node = Get-ChildItem -LiteralPath (Join-Path $RepoRoot "runtime\node") -Filter node.exe -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "node-v22\.20\.0-win-x64" } |
    Select-Object -First 1

  if ($node) {
    return $node.DirectoryName
  }

  return $null
}

function Get-ImmichNodeExe {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $nodeDir = Get-ImmichNodeDir -RepoRoot $RepoRoot
  if (-not $nodeDir) {
    return $null
  }

  return Join-Path $nodeDir "node.exe"
}

function Get-ImmichPnpmCjs {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $pnpm = Join-Path $RepoRoot "runtime\tools\pnpm\package\bin\pnpm.cjs"
  if (Test-Path -LiteralPath $pnpm -PathType Leaf) {
    return $pnpm
  }

  return $null
}

function Get-ImmichPythonExe {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $python = Get-ChildItem -LiteralPath (Join-Path $RepoRoot "runtime\python") -Filter python.exe -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "cpython-3\.12" } |
    Select-Object -First 1

  if ($python) {
    return $python.FullName
  }

  return $null
}

function Repair-ImmichMlVenvConfig {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $venvPython = Join-Path $RepoRoot "machine-learning\.venv\Scripts\python.exe"
  $python = Get-ImmichPythonExe -RepoRoot $RepoRoot
  if ((-not $python) -or (-not (Test-Path -LiteralPath $venvPython -PathType Leaf))) {
    return
  }

  $pythonHome = Split-Path -Parent $python
  $cfg = @"
home = $pythonHome
implementation = CPython
version_info = 3.12.13.final.0
virtualenv = 20.35.4
include-system-site-packages = false
base-prefix = $pythonHome
base-exec-prefix = $pythonHome
base-executable = $python
"@
  Set-Content -LiteralPath (Join-Path $RepoRoot "machine-learning\.venv\pyvenv.cfg") -Value $cfg -Encoding ASCII
}

function Assert-ImmichLocalRuntime {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [switch]$RequireDatabase,
    [switch]$RequireMachineLearning
  )

  $node = Get-ImmichNodeExe -RepoRoot $RepoRoot
  $pnpm = Get-ImmichPnpmCjs -RepoRoot $RepoRoot
  $python = Get-ImmichPythonExe -RepoRoot $RepoRoot
  $uv = Join-Path $RepoRoot "runtime\tools\uv\uv.exe"
  $binaryen = Join-Path $RepoRoot "runtime\tools\binaryen\bin\wasm-merge.exe"
  $extism = Join-Path $RepoRoot "runtime\tools\extism-js\extism-js.exe"

  foreach ($item in @(
    @{ Path = $node; Name = "bundled Node.js" },
    @{ Path = $pnpm; Name = "bundled pnpm" },
    @{ Path = $python; Name = "bundled Python 3.12" },
    @{ Path = $uv; Name = "bundled uv" },
    @{ Path = $binaryen; Name = "bundled Binaryen" },
    @{ Path = $extism; Name = "bundled extism-js" }
  )) {
    if (-not $item.Path -or -not (Test-Path -LiteralPath $item.Path -PathType Leaf)) {
      throw "$($item.Name) is missing and automatic runtime setup did not complete."
    }
  }

  if ($RequireDatabase) {
    foreach ($item in @(
      @{ Path = (Join-Path $RepoRoot "runtime\postgres\bin\postgres.exe"); Name = "bundled PostgreSQL" },
      @{ Path = (Join-Path $RepoRoot "runtime\postgres\share\extension\vector.control"); Name = "bundled pgvector" },
      @{ Path = (Join-Path $RepoRoot "runtime\redis\redis-server.exe"); Name = "bundled Redis" }
    )) {
      if (-not (Test-Path -LiteralPath $item.Path -PathType Leaf)) {
        throw "$($item.Name) is missing and automatic runtime setup did not complete."
      }
    }
  }

  if ($RequireMachineLearning) {
    $venvPython = Join-Path $RepoRoot "machine-learning\.venv\Scripts\python.exe"
    if (-not (Test-Path -LiteralPath $venvPython -PathType Leaf)) {
      throw "machine-learning venv is missing and automatic runtime setup did not complete."
    }
    Repair-ImmichMlVenvConfig -RepoRoot $RepoRoot
  }
}

function Add-ImmichRuntimeToPath {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $nodeDir = Get-ImmichNodeDir -RepoRoot $RepoRoot
  $paths = @(
    $nodeDir,
    (Join-Path $RepoRoot "runtime\tools\uv"),
    (Join-Path $RepoRoot "runtime\tools\binaryen\bin"),
    (Join-Path $RepoRoot "runtime\tools\extism-js")
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) }

  $env:PATH = (($paths + @($env:PATH)) -join ";")
}

Add-ImmichRuntimeToPath -RepoRoot $RepoRoot
