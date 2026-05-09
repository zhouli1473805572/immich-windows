$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$script:ImmichRuntimeVersions = @{
  Node = "22.20.0"
  Pnpm = "10.33.1"
  Uv = "0.11.11"
  Python = "3.12"
  Postgres = "14.20-1"
  Pgvector = "0.8.2_14.20"
  Redis = "6.2.22"
  Binaryen = "129"
  ExtismJs = "1.6.0"
}

$script:ImmichRuntimeUrls = @{
  Node = "https://nodejs.org/dist/v$($script:ImmichRuntimeVersions.Node)/node-v$($script:ImmichRuntimeVersions.Node)-win-x64.zip"
  Uv = "https://github.com/astral-sh/uv/releases/download/$($script:ImmichRuntimeVersions.Uv)/uv-x86_64-pc-windows-msvc.zip"
  Postgres = "https://get.enterprisedb.com/postgresql/postgresql-$($script:ImmichRuntimeVersions.Postgres)-windows-x64-binaries.zip"
  Pgvector = "https://github.com/andreiramani/pgvector_pgsql_windows/releases/download/$($script:ImmichRuntimeVersions.Pgvector)/vector.v0.8.2-pg14.zip"
  Redis = "https://github.com/redis-windows/redis-windows/releases/download/$($script:ImmichRuntimeVersions.Redis)/Redis-$($script:ImmichRuntimeVersions.Redis)-Windows-x64-msys2.zip"
  Binaryen = "https://github.com/WebAssembly/binaryen/releases/download/version_$($script:ImmichRuntimeVersions.Binaryen)/binaryen-version_$($script:ImmichRuntimeVersions.Binaryen)-x86_64-windows.tar.gz"
  ExtismJs = "https://github.com/extism/js-pdk/releases/download/v$($script:ImmichRuntimeVersions.ExtismJs)/extism-js-x86_64-windows-v$($script:ImmichRuntimeVersions.ExtismJs).gz"
}

function Write-ImmichRuntimeStep {
  param([string]$Message)
  Write-Host "runtime: $Message"
}

function Save-ImmichRuntimeFile {
  param(
    [Parameter(Mandatory = $true)][string]$Url,
    [Parameter(Mandatory = $true)][string]$OutFile,
    [switch]$NoRevoke
  )

  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
  if (Test-Path -LiteralPath $OutFile -PathType Leaf) {
    return
  }

  Write-ImmichRuntimeStep "downloading $Url"
  $args = @("-L", "--retry", "10", "--retry-delay", "5", "--retry-all-errors", "-o", $OutFile, $Url)
  if ($NoRevoke) {
    $args = @("--ssl-no-revoke") + $args
  }
  & curl.exe @args
  if ($LASTEXITCODE -ne 0) {
    throw "Download failed: $Url"
  }
}

function New-ImmichRuntimeTempDir {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $tempRoot = Join-Path $RepoRoot "runtime\tools\_downloads"
  New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
  $dir = Join-Path $tempRoot ([Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  return $dir
}

function Expand-ImmichZipToTemp {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $true)][string]$Archive
  )

  $temp = New-ImmichRuntimeTempDir -RepoRoot $RepoRoot
  Expand-Archive -LiteralPath $Archive -DestinationPath $temp -Force
  return $temp
}

function Expand-ImmichGzipFile {
  param(
    [Parameter(Mandatory = $true)][string]$Archive,
    [Parameter(Mandatory = $true)][string]$OutFile
  )

  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
  $input = [System.IO.File]::OpenRead($Archive)
  try {
    $gzip = [System.IO.Compression.GzipStream]::new($input, [System.IO.Compression.CompressionMode]::Decompress)
    try {
      $output = [System.IO.File]::Create($OutFile)
      try {
        $gzip.CopyTo($output)
      } finally {
        $output.Dispose()
      }
    } finally {
      $gzip.Dispose()
    }
  } finally {
    $input.Dispose()
  }
}

function Copy-ImmichDirectoryContents {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination
  )

  New-Item -ItemType Directory -Force -Path $Destination | Out-Null
  Copy-Item -Path (Join-Path $Source "*") -Destination $Destination -Recurse -Force
}

function Get-ImmichNodeDir {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $node = Get-ChildItem -LiteralPath (Join-Path $RepoRoot "runtime\node") -Filter node.exe -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "node-v$($script:ImmichRuntimeVersions.Node -replace '\.', '\.')-win-x64" } |
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

function Ensure-ImmichUv {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $uvDir = Join-Path $RepoRoot "runtime\tools\uv"
  $uv = Join-Path $uvDir "uv.exe"
  if (Test-Path -LiteralPath $uv -PathType Leaf) {
    return $uv
  }

  Write-ImmichRuntimeStep "installing uv"
  $zip = Join-Path $uvDir "uv-x86_64-pc-windows-msvc.zip"
  Save-ImmichRuntimeFile -Url $script:ImmichRuntimeUrls.Uv -OutFile $zip
  New-Item -ItemType Directory -Force -Path $uvDir | Out-Null
  Expand-Archive -LiteralPath $zip -DestinationPath $uvDir -Force
  if (-not (Test-Path -LiteralPath $uv -PathType Leaf)) {
    throw "uv.exe was not installed to $uv"
  }
  return $uv
}

function Ensure-ImmichNodeAndPnpm {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $nodeDir = Get-ImmichNodeDir -RepoRoot $RepoRoot
  if (-not $nodeDir) {
    Write-ImmichRuntimeStep "installing Node.js"
    $zip = Join-Path $RepoRoot "runtime\tools\node-v$($script:ImmichRuntimeVersions.Node)-win-x64.zip"
    Save-ImmichRuntimeFile -Url $script:ImmichRuntimeUrls.Node -OutFile $zip
    New-Item -ItemType Directory -Force -Path (Join-Path $RepoRoot "runtime\node") | Out-Null
    Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $RepoRoot "runtime\node") -Force
    $nodeDir = Get-ImmichNodeDir -RepoRoot $RepoRoot
  }

  if (-not $nodeDir) {
    throw "Node.js runtime was not installed."
  }

  $nodeExe = Join-Path $nodeDir "node.exe"
  $pnpm = Get-ImmichPnpmCjs -RepoRoot $RepoRoot
  if (-not $pnpm) {
    Write-ImmichRuntimeStep "installing pnpm"
    $pnpmDir = Join-Path $RepoRoot "runtime\tools\pnpm"
    New-Item -ItemType Directory -Force -Path $pnpmDir | Out-Null
    Push-Location $pnpmDir
    try {
      & (Join-Path $nodeDir "npm.cmd") "pack" "pnpm@$($script:ImmichRuntimeVersions.Pnpm)"
      if ($LASTEXITCODE -ne 0) {
        throw "npm pack pnpm failed."
      }
      tar.exe "-xzf" "pnpm-$($script:ImmichRuntimeVersions.Pnpm).tgz"
      Remove-Item -LiteralPath "pnpm-$($script:ImmichRuntimeVersions.Pnpm).tgz" -Force -ErrorAction SilentlyContinue
    } finally {
      Pop-Location
    }
    $pnpm = Get-ImmichPnpmCjs -RepoRoot $RepoRoot
  }

  if (-not $pnpm) {
    throw "pnpm runtime was not installed."
  }

  return @{ NodeDir = $nodeDir; NodeExe = $nodeExe; PnpmCjs = $pnpm }
}

function Ensure-ImmichPython {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $python = Get-ImmichPythonExe -RepoRoot $RepoRoot
  if ($python) {
    return $python
  }

  Write-ImmichRuntimeStep "installing Python $($script:ImmichRuntimeVersions.Python)"
  $uv = Ensure-ImmichUv -RepoRoot $RepoRoot
  $pythonRoot = Join-Path $RepoRoot "runtime\python"
  New-Item -ItemType Directory -Force -Path $pythonRoot | Out-Null
  & $uv "python" "install" $script:ImmichRuntimeVersions.Python "--install-dir" $pythonRoot "--no-registry" "--compile-bytecode"
  if ($LASTEXITCODE -ne 0) {
    throw "uv python install failed."
  }

  $python = Get-ImmichPythonExe -RepoRoot $RepoRoot
  if (-not $python) {
    throw "Python runtime was not installed."
  }
  return $python
}

function Ensure-ImmichBinaryen {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $target = Join-Path $RepoRoot "runtime\tools\binaryen"
  $wasmMerge = Join-Path $target "bin\wasm-merge.exe"
  if (Test-Path -LiteralPath $wasmMerge -PathType Leaf) {
    return $target
  }

  Write-ImmichRuntimeStep "installing Binaryen"
  $archive = Join-Path $RepoRoot "runtime\tools\binaryen-version_$($script:ImmichRuntimeVersions.Binaryen)-x86_64-windows.tar.gz"
  Save-ImmichRuntimeFile -Url $script:ImmichRuntimeUrls.Binaryen -OutFile $archive

  $temp = New-ImmichRuntimeTempDir -RepoRoot $RepoRoot
  try {
    tar.exe "-xzf" $archive "-C" $temp
    if ($LASTEXITCODE -ne 0) {
      throw "Binaryen archive extraction failed."
    }
    $source = Get-ChildItem -LiteralPath $temp -Directory | Select-Object -First 1
    if (-not $source) {
      throw "Binaryen archive had no root directory."
    }
    Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue
    Copy-ImmichDirectoryContents -Source $source.FullName -Destination $target
  } finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
  }

  return $target
}

function Ensure-ImmichExtismJs {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $targetDir = Join-Path $RepoRoot "runtime\tools\extism-js"
  $exe = Join-Path $targetDir "extism-js.exe"
  if (Test-Path -LiteralPath $exe -PathType Leaf) {
    return $exe
  }

  Write-ImmichRuntimeStep "installing extism-js"
  $archive = Join-Path $targetDir "extism-js-x86_64-windows-v$($script:ImmichRuntimeVersions.ExtismJs).gz"
  Save-ImmichRuntimeFile -Url $script:ImmichRuntimeUrls.ExtismJs -OutFile $archive
  Expand-ImmichGzipFile -Archive $archive -OutFile $exe
  return $exe
}

function Ensure-ImmichPostgres {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $target = Join-Path $RepoRoot "runtime\postgres"
  $postgresExe = Join-Path $target "bin\postgres.exe"
  if (-not (Test-Path -LiteralPath $postgresExe -PathType Leaf)) {
    Write-ImmichRuntimeStep "installing PostgreSQL"
    $zip = Join-Path $RepoRoot "runtime\tools\postgresql-$($script:ImmichRuntimeVersions.Postgres)-windows-x64-binaries.zip"
    Save-ImmichRuntimeFile -Url $script:ImmichRuntimeUrls.Postgres -OutFile $zip
    $temp = Expand-ImmichZipToTemp -RepoRoot $RepoRoot -Archive $zip
    try {
      $source = Get-ChildItem -LiteralPath $temp -Directory -Recurse |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "bin\postgres.exe") -PathType Leaf } |
        Select-Object -First 1
      if (-not $source) {
        throw "PostgreSQL archive did not contain bin\postgres.exe."
      }
      Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue
      Copy-ImmichDirectoryContents -Source $source.FullName -Destination $target
    } finally {
      Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  Ensure-ImmichPgvector -RepoRoot $RepoRoot
  return $postgresExe
}

function Ensure-ImmichPgvector {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $pgRoot = Join-Path $RepoRoot "runtime\postgres"
  $control = Join-Path $pgRoot "share\extension\vector.control"
  $dll = Join-Path $pgRoot "lib\vector.dll"
  if ((Test-Path -LiteralPath $control -PathType Leaf) -and (Test-Path -LiteralPath $dll -PathType Leaf)) {
    return
  }

  Write-ImmichRuntimeStep "installing pgvector"
  $zip = Join-Path $RepoRoot "runtime\tools\vector.v0.8.2-pg14.zip"
  Save-ImmichRuntimeFile -Url $script:ImmichRuntimeUrls.Pgvector -OutFile $zip
  $temp = Expand-ImmichZipToTemp -RepoRoot $RepoRoot -Archive $zip
  try {
    $vectorControl = Get-ChildItem -LiteralPath $temp -Filter "vector.control" -Recurse | Select-Object -First 1
    $vectorDll = Get-ChildItem -LiteralPath $temp -Filter "vector.dll" -Recurse | Select-Object -First 1
    if ((-not $vectorControl) -or (-not $vectorDll)) {
      throw "pgvector archive did not contain vector.control and vector.dll."
    }

    New-Item -ItemType Directory -Force -Path (Join-Path $pgRoot "share\extension"), (Join-Path $pgRoot "lib") | Out-Null
    Copy-Item -Path (Join-Path $vectorControl.DirectoryName "vector*") -Destination (Join-Path $pgRoot "share\extension") -Force
    Copy-Item -LiteralPath $vectorDll.FullName -Destination $dll -Force
  } finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Ensure-ImmichRedis {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $target = Join-Path $RepoRoot "runtime\redis"
  $redisExe = Join-Path $target "redis-server.exe"
  if (Test-Path -LiteralPath $redisExe -PathType Leaf) {
    return $redisExe
  }

  Write-ImmichRuntimeStep "installing Redis"
  $zip = Join-Path $RepoRoot "runtime\tools\Redis-$($script:ImmichRuntimeVersions.Redis)-Windows-x64-msys2.zip"
  Save-ImmichRuntimeFile -Url $script:ImmichRuntimeUrls.Redis -OutFile $zip
  $temp = Expand-ImmichZipToTemp -RepoRoot $RepoRoot -Archive $zip
  try {
    $sourceExe = Get-ChildItem -LiteralPath $temp -Filter "redis-server.exe" -Recurse | Select-Object -First 1
    if (-not $sourceExe) {
      throw "Redis archive did not contain redis-server.exe."
    }
    Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue
    Copy-ImmichDirectoryContents -Source $sourceExe.DirectoryName -Destination $target
  } finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
  }

  return $redisExe
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

function Ensure-ImmichMachineLearningVenv {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $venvPython = Join-Path $RepoRoot "machine-learning\.venv\Scripts\python.exe"
  if (Test-Path -LiteralPath $venvPython -PathType Leaf) {
    Repair-ImmichMlVenvConfig -RepoRoot $RepoRoot
    return $venvPython
  }

  Write-ImmichRuntimeStep "creating machine-learning venv"
  $uv = Ensure-ImmichUv -RepoRoot $RepoRoot
  $python = Ensure-ImmichPython -RepoRoot $RepoRoot
  Set-Content -LiteralPath (Join-Path $RepoRoot "machine-learning\.python-version") -Value "3.12" -Encoding ASCII
  Push-Location (Join-Path $RepoRoot "machine-learning")
  try {
    & $uv "sync" "--python" $python "--frozen" "--no-dev" "--extra" "cpu"
    if ($LASTEXITCODE -ne 0) {
      throw "machine-learning venv creation failed."
    }
  } finally {
    Pop-Location
  }

  Repair-ImmichMlVenvConfig -RepoRoot $RepoRoot
  return $venvPython
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

function Ensure-ImmichRuntime {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [switch]$IncludeDatabase,
    [switch]$IncludeMachineLearning,
    [switch]$IncludeBuildTools
  )

  Ensure-ImmichUv -RepoRoot $RepoRoot | Out-Null
  Ensure-ImmichNodeAndPnpm -RepoRoot $RepoRoot | Out-Null
  Ensure-ImmichPython -RepoRoot $RepoRoot | Out-Null
  Ensure-ImmichBinaryen -RepoRoot $RepoRoot | Out-Null
  Ensure-ImmichExtismJs -RepoRoot $RepoRoot | Out-Null

  if ($IncludeDatabase) {
    Ensure-ImmichPostgres -RepoRoot $RepoRoot | Out-Null
    Ensure-ImmichRedis -RepoRoot $RepoRoot | Out-Null
  }

  if ($IncludeMachineLearning) {
    Ensure-ImmichMachineLearningVenv -RepoRoot $RepoRoot | Out-Null
  }

  Add-ImmichRuntimeToPath -RepoRoot $RepoRoot
}
