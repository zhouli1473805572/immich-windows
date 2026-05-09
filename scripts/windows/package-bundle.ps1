param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$OutputZip,
  [switch]$SkipBuildToolsInstall,
  [switch]$SkipWebBuild,
  [switch]$SkipModelPreload,
  [switch]$KeepServicesRunning,
  [switch]$KeepLocalData,
  [switch]$KeepLocalConfig,
  [switch]$NoArchive
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Assert-File {
  param([string]$Path, [string]$Name)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing $Name`: $Path"
  }
}

function Assert-Directory {
  param([string]$Path, [string]$Name)
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    throw "Missing $Name`: $Path"
  }
}

function Download-File {
  param(
    [string]$Url,
    [string]$OutFile,
    [switch]$NoRevoke
  )

  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
  $args = @("-L", "--retry", "10", "--retry-delay", "5", "--retry-all-errors", "-o", $OutFile, $Url)
  if ($NoRevoke) {
    $args = @("--ssl-no-revoke") + $args
  }

  & curl.exe @args
  if ($LASTEXITCODE -ne 0) {
    throw "Download failed: $Url"
  }
}

function Get-BundledPython {
  $python = Get-ChildItem -LiteralPath (Join-Path $RepoRoot "runtime\python") -Filter python.exe -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "cpython-3\.12" } |
    Select-Object -First 1

  if ($python) {
    return $python.FullName
  }

  return $null
}

function Get-BundledNodeDir {
  $node = Get-ChildItem -LiteralPath (Join-Path $RepoRoot "runtime\node") -Filter node.exe -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "node-v22\.20\.0-win-x64" } |
    Select-Object -First 1

  if ($node) {
    return $node.DirectoryName
  }

  return $null
}

function Test-Port {
  param([int]$Port)
  try {
    $client = [System.Net.Sockets.TcpClient]::new()
    $iar = $client.BeginConnect("127.0.0.1", $Port, $null, $null)
    $ok = $iar.AsyncWaitHandle.WaitOne(500, $false)
    if ($ok) {
      $client.EndConnect($iar)
      $client.Close()
      return $true
    }
    $client.Close()
    return $false
  } catch {
    return $false
  }
}

function Stop-ProcessTreeByRepo {
  $repoFull = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\')
  foreach ($name in @("node", "python", "postgres", "redis-server")) {
    Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
      try {
        $path = $_.Path
        if ($path -and [System.IO.Path]::GetFullPath($path).StartsWith($repoFull, [System.StringComparison]::OrdinalIgnoreCase)) {
          Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
      } catch {
      }
    }
  }
}

function Stop-RuntimeServices {
  Write-Step "Stopping bundled runtime services"

  $pgCtl = Join-Path $RepoRoot "runtime\postgres\bin\pg_ctl.exe"
  $pgData = Join-Path $RepoRoot "runtime\data\postgres"
  if ((Test-Path -LiteralPath $pgCtl -PathType Leaf) -and (Test-Path -LiteralPath (Join-Path $pgData "PG_VERSION") -PathType Leaf)) {
    & $pgCtl "-D" $pgData "stop" "-m" "fast" "-w" | Out-Null
  }

  $redisCli = Join-Path $RepoRoot "runtime\redis\redis-cli.exe"
  if (Test-Path -LiteralPath $redisCli -PathType Leaf) {
    & $redisCli "-p" "63790" "shutdown" | Out-Null
  }

  Stop-ProcessTreeByRepo
}

function Clear-DirectoryContents {
  param([Parameter(Mandatory = $true)][string]$Path)

  New-Item -ItemType Directory -Force -Path $Path | Out-Null
  Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

function Reset-LocalBundleData {
  if ($KeepLocalData) {
    Write-Step "Keeping local runtime data"
    return
  }

  Write-Step "Cleaning local runtime data for a fresh bundle"

  Clear-DirectoryContents -Path (Join-Path $RepoRoot "runtime\data\postgres")
  Clear-DirectoryContents -Path (Join-Path $RepoRoot "runtime\data\redis")
  Clear-DirectoryContents -Path (Join-Path $RepoRoot "runtime\logs")
  Clear-DirectoryContents -Path (Join-Path $RepoRoot "upload")
  Clear-DirectoryContents -Path (Join-Path $RepoRoot "runtime\hf-home")
  Clear-DirectoryContents -Path (Join-Path $RepoRoot ".cache\immich_ml")

  if (-not $KeepLocalConfig) {
    Remove-Item -LiteralPath (Join-Path $RepoRoot "runtime\immich-windows.env") -Force -ErrorAction SilentlyContinue
  }
}

function Install-BuildToolsIfNeeded {
  Write-Step "Checking Microsoft C++ Build Tools"

  $vswhereCandidates = @(
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe",
    "${env:ProgramFiles}\Microsoft Visual Studio\Installer\vswhere.exe"
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) }

  foreach ($vswhere in $vswhereCandidates) {
    $installPath = & $vswhere "-latest" "-products" "*" "-requires" "Microsoft.VisualStudio.Component.VC.Tools.x86.x64" "-property" "installationPath"
    if ($LASTEXITCODE -eq 0 -and $installPath) {
      Write-Host "Found C++ Build Tools: $installPath"
      return
    }
  }

  if ($SkipBuildToolsInstall) {
    throw "Microsoft C++ Build Tools was not found. Run without -SkipBuildToolsInstall to install it automatically."
  }

  $installer = Join-Path $RepoRoot "runtime\tools\vs_BuildTools.exe"
  Download-File -Url "https://aka.ms/vs/17/release/vs_BuildTools.exe" -OutFile $installer

  $args = @(
    "--quiet",
    "--wait",
    "--norestart",
    "--nocache",
    "--add", "Microsoft.VisualStudio.Workload.VCTools",
    "--includeRecommended"
  )

  $process = Start-Process -FilePath $installer -ArgumentList $args -Wait -PassThru
  if (($process.ExitCode -ne 0) -and ($process.ExitCode -ne 3010)) {
    throw "Visual Studio Build Tools installer failed with exit code $($process.ExitCode)."
  }

  Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue
}

function Ensure-BundledPython {
  Write-Step "Checking bundled Python 3.12"

  $python = Get-BundledPython
  if ($python) {
    Write-Host "Found Python: $python"
    return $python
  }

  $uv = Join-Path $RepoRoot "runtime\tools\uv\uv.exe"
  Assert-File $uv "uv"

  $pythonRoot = Join-Path $RepoRoot "runtime\python"
  New-Item -ItemType Directory -Force -Path $pythonRoot | Out-Null
  & $uv "python" "install" "3.12" "--install-dir" $pythonRoot "--no-registry" "--compile-bytecode"
  if ($LASTEXITCODE -ne 0) {
    throw "uv python install failed."
  }

  $python = Get-BundledPython
  if (-not $python) {
    throw "Bundled Python 3.12 was not installed."
  }

  return $python
}

function Ensure-BundledNode {
  Write-Step "Checking bundled Node.js and pnpm"

  $nodeDir = Get-BundledNodeDir
  if (-not $nodeDir) {
    $nodeZip = Join-Path $RepoRoot "runtime\tools\node-v22.20.0-win-x64.zip"
    Download-File -Url "https://nodejs.org/dist/v22.20.0/node-v22.20.0-win-x64.zip" -OutFile $nodeZip
    New-Item -ItemType Directory -Force -Path (Join-Path $RepoRoot "runtime\node") | Out-Null
    Expand-Archive -LiteralPath $nodeZip -DestinationPath (Join-Path $RepoRoot "runtime\node") -Force
    Remove-Item -LiteralPath $nodeZip -Force -ErrorAction SilentlyContinue
    $nodeDir = Get-BundledNodeDir
  }

  if (-not $nodeDir) {
    throw "Bundled Node.js was not installed."
  }

  $nodeExe = Join-Path $nodeDir "node.exe"
  $pnpmCjs = Join-Path $RepoRoot "runtime\tools\pnpm\package\bin\pnpm.cjs"
  if (-not (Test-Path -LiteralPath $pnpmCjs -PathType Leaf)) {
    $pnpmDir = Join-Path $RepoRoot "runtime\tools\pnpm"
    New-Item -ItemType Directory -Force -Path $pnpmDir | Out-Null
    Push-Location $pnpmDir
    try {
      & (Join-Path $nodeDir "npm.cmd") "pack" "pnpm@10.33.1"
      if ($LASTEXITCODE -ne 0) {
        throw "npm pack pnpm failed."
      }
      tar.exe -xzf "pnpm-10.33.1.tgz"
      Remove-Item -LiteralPath "pnpm-10.33.1.tgz" -Force -ErrorAction SilentlyContinue
    } finally {
      Pop-Location
    }
  }

  Assert-File $nodeExe "bundled node.exe"
  Assert-File $pnpmCjs "bundled pnpm.cjs"
  return @{ NodeDir = $nodeDir; NodeExe = $nodeExe; PnpmCjs = $pnpmCjs }
}

function Ensure-MachineLearningVenv {
  param([string]$PythonExe)

  Write-Step "Building machine-learning virtual environment"

  $uv = Join-Path $RepoRoot "runtime\tools\uv\uv.exe"
  Assert-File $uv "uv"

  Set-Content -LiteralPath (Join-Path $RepoRoot "machine-learning\.python-version") -Value "3.12" -Encoding ASCII

  Push-Location (Join-Path $RepoRoot "machine-learning")
  try {
    & $uv "sync" "--python" $PythonExe "--frozen" "--no-dev" "--extra" "cpu"
    if ($LASTEXITCODE -ne 0) {
      throw "uv sync for machine-learning failed."
    }
  } finally {
    Pop-Location
  }

  $venvPython = Join-Path $RepoRoot "machine-learning\.venv\Scripts\python.exe"
  Assert-File $venvPython "machine-learning venv python"

  $pythonHome = Split-Path -Parent $PythonExe
  $cfg = @"
home = $pythonHome
implementation = CPython
version_info = 3.12.13.final.0
virtualenv = 20.35.4
include-system-site-packages = false
base-prefix = $pythonHome
base-exec-prefix = $pythonHome
base-executable = $PythonExe
"@
  Set-Content -LiteralPath (Join-Path $RepoRoot "machine-learning\.venv\pyvenv.cfg") -Value $cfg -Encoding ASCII

  & $venvPython "-c" "import insightface, onnxruntime, cv2; print('ml-imports-ok')"
  if ($LASTEXITCODE -ne 0) {
    throw "machine-learning dependency import check failed."
  }
}

function Build-Web {
  param([hashtable]$Node)

  if ($SkipWebBuild) {
    Write-Step "Skipping web build"
    return
  }

  Write-Step "Building web frontend"

  $env:PATH = "$($Node.NodeDir);$(Join-Path $RepoRoot 'runtime\tools\uv');$(Join-Path $RepoRoot 'runtime\tools\binaryen\bin');$env:PATH"
  $env:IMMICH_BUILD = "windows-$(Get-Date -Format yyyyMMddHHmmss)"

  Push-Location $RepoRoot
  try {
    Remove-Item -LiteralPath (Join-Path $RepoRoot "web\build") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $RepoRoot "web\.svelte-kit\output") -Recurse -Force -ErrorAction SilentlyContinue

    & $Node.NodeExe $Node.PnpmCjs "--filter" "@immich/sdk" "--filter" "immich-web" "build"
    if ($LASTEXITCODE -ne 0) {
      throw "web build failed."
    }

    $www = Join-Path $RepoRoot "build\www"
    Remove-Item -LiteralPath $www -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $www | Out-Null
    Copy-Item -Path (Join-Path $RepoRoot "web\build\*") -Destination $www -Recurse -Force

    $plugin = Join-Path $RepoRoot "plugins\dist\plugin.wasm"
    if (Test-Path -LiteralPath $plugin -PathType Leaf) {
      $pluginOut = Join-Path $RepoRoot "build\corePlugin\dist"
      New-Item -ItemType Directory -Force -Path $pluginOut | Out-Null
      Copy-Item -LiteralPath $plugin -Destination (Join-Path $pluginOut "plugin.wasm") -Force
    }
  } finally {
    Pop-Location
  }
}

function Build-Manager {
  Write-Step "Building native manager"

  $csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
  Assert-File $csc "C# compiler"

  New-Item -ItemType Directory -Force -Path (Join-Path $RepoRoot "build") | Out-Null
  Push-Location $RepoRoot
  try {
    & $csc "/nologo" "/target:winexe" "/out:build\ImmichManager.exe" "/r:System.dll" "/r:System.Core.dll" "/r:System.Drawing.dll" "/r:System.Windows.Forms.dll" "manager-native\ImmichManager.cs"
    if ($LASTEXITCODE -ne 0) {
      throw "manager build failed."
    }
  } finally {
    Pop-Location
  }
}

function Ensure-OcrModels {
  Write-Step "Checking OCR models"

  $ocrDir = Join-Path $RepoRoot "runtime\models\ocr\PP-OCRv5_mobile"
  $det = Join-Path $ocrDir "detection\model.onnx"
  $rec = Join-Path $ocrDir "recognition\model.onnx"

  if (-not (Test-Path -LiteralPath $det -PathType Leaf)) {
    Download-File -NoRevoke -Url "https://modelscope.cn/models/rapidocr/RapidOCR/resolve/master/PP-OCRv5/mobile/det/ch_PP-OCRv5_mobile_det_infer.onnx" -OutFile $det
  }
  if (-not (Test-Path -LiteralPath $rec -PathType Leaf)) {
    Download-File -NoRevoke -Url "https://modelscope.cn/models/rapidocr/RapidOCR/resolve/master/PP-OCRv5/mobile/rec/ch_PP-OCRv5_rec_mobile_infer.onnx" -OutFile $rec
  }

  Assert-File $det "OCR detection model"
  Assert-File $rec "OCR recognition model"
}

function Preload-Models {
  if ($SkipModelPreload) {
    Write-Step "Skipping model preload"
    return
  }

  Ensure-OcrModels

  Write-Step "Preloading ML models"

  $python = Join-Path $RepoRoot "machine-learning\.venv\Scripts\python.exe"
  Assert-File $python "machine-learning venv python"

  $logs = Join-Path $RepoRoot "runtime\logs"
  New-Item -ItemType Directory -Force -Path $logs | Out-Null

  $env:MACHINE_LEARNING_CACHE_FOLDER = Join-Path $RepoRoot "runtime\models"
  $env:IMMICH_HOST = "127.0.0.1"
  $env:IMMICH_PORT = "3003"
  $env:PORT = "3003"
  $env:MACHINE_LEARNING_HOST = "127.0.0.1"
  $env:MACHINE_LEARNING_PORT = "3003"
  $env:MACHINE_LEARNING_PRELOAD__CLIP__TEXTUAL = "ViT-B-32__openai"
  $env:MACHINE_LEARNING_PRELOAD__CLIP__VISUAL = "ViT-B-32__openai"
  $env:MACHINE_LEARNING_PRELOAD__FACIAL_RECOGNITION__DETECTION = "buffalo_l"
  $env:MACHINE_LEARNING_PRELOAD__FACIAL_RECOGNITION__RECOGNITION = "buffalo_l"
  $env:MACHINE_LEARNING_PRELOAD__OCR__DETECTION = "PP-OCRv5_mobile"
  $env:MACHINE_LEARNING_PRELOAD__OCR__RECOGNITION = "PP-OCRv5_mobile"

  $stdout = Join-Path $logs "package-ml-preload.out.log"
  $stderr = Join-Path $logs "package-ml-preload.err.log"
  Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue

  $process = Start-Process -FilePath $python -ArgumentList @("-m", "immich_ml", "--host", "127.0.0.1", "--port", "3003") -WorkingDirectory (Join-Path $RepoRoot "machine-learning") -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden -PassThru

  try {
    $deadline = (Get-Date).AddMinutes(30)
    while ((Get-Date) -lt $deadline) {
      if ($process.HasExited) {
        $out = if (Test-Path -LiteralPath $stdout) { Get-Content -LiteralPath $stdout -Raw } else { "" }
        $err = if (Test-Path -LiteralPath $stderr) { Get-Content -LiteralPath $stderr -Raw } else { "" }
        throw "ML preload process exited early.`n$out`n$err"
      }
      if (Test-Port 3003) {
        break
      }
      Start-Sleep -Seconds 2
    }

    if (-not (Test-Port 3003)) {
      throw "ML preload did not open port 3003 in time."
    }
  } finally {
    if (-not $process.HasExited) {
      Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
  }
}

function Write-RunReadme {
  Write-Step "Checking bundle readmes"

  Assert-File (Join-Path $RepoRoot "README.md") "root readme"
  Assert-File (Join-Path $RepoRoot "WINDOWS-BUNDLE-README.txt") "bundle readme"
}

function Verify-Bundle {
  Write-Step "Verifying bundle files"

  Assert-File (Join-Path $RepoRoot "build\ImmichManager.exe") "manager exe"
  Assert-File (Join-Path $RepoRoot "runtime\postgres\bin\postgres.exe") "PostgreSQL"
  Assert-File (Join-Path $RepoRoot "runtime\redis\redis-server.exe") "Redis"
  Assert-File (Join-Path $RepoRoot "machine-learning\.venv\Scripts\python.exe") "ML venv"
  Assert-File (Join-Path $RepoRoot "runtime\tools\pnpm\package\bin\pnpm.cjs") "pnpm"
  Assert-Directory (Join-Path $RepoRoot "build\www") "web build"
  Assert-File (Join-Path $RepoRoot "runtime\models\clip\ViT-B-32__openai\textual\model.onnx") "CLIP textual model"
  Assert-File (Join-Path $RepoRoot "runtime\models\clip\ViT-B-32__openai\visual\model.onnx") "CLIP visual model"
  Assert-File (Join-Path $RepoRoot "runtime\models\facial-recognition\buffalo_l\detection\model.onnx") "face detection model"
  Assert-File (Join-Path $RepoRoot "runtime\models\facial-recognition\buffalo_l\recognition\model.onnx") "face recognition model"
  Assert-File (Join-Path $RepoRoot "runtime\models\ocr\PP-OCRv5_mobile\detection\model.onnx") "OCR detection model"
  Assert-File (Join-Path $RepoRoot "runtime\models\ocr\PP-OCRv5_mobile\recognition\model.onnx") "OCR recognition model"
}

function New-BundleArchive {
  if ($NoArchive) {
    Write-Step "Skipping archive creation"
    return
  }

  if (-not $OutputZip) {
    $OutputZip = Join-Path (Split-Path -Parent $RepoRoot) "immich-window-bundle.zip"
  }

  $outputFull = [System.IO.Path]::GetFullPath($OutputZip)
  $repoFull = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\') + "\"
  if ($outputFull.StartsWith($repoFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "OutputZip must be outside the repo to avoid packaging itself: $outputFull"
  }

  Write-Step "Creating archive: $outputFull"

  Reset-LocalBundleData

  Get-ChildItem -LiteralPath (Join-Path $RepoRoot "runtime\logs") -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  Get-ChildItem -LiteralPath (Join-Path $RepoRoot "runtime\tools") -Include "*.zip", "*.tgz" -File -Recurse -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $outputFull -Force -ErrorAction SilentlyContinue

  Push-Location $RepoRoot
  try {
    tar.exe "-a" "-cf" $outputFull `
      "--exclude=.cache/*" `
      "--exclude=runtime/data/*" `
      "--exclude=runtime/data/postgres/*" `
      "--exclude=runtime/data/redis/*" `
      "--exclude=runtime/logs/*" `
      "--exclude=runtime/hf-home/*" `
      "--exclude=runtime/immich-windows.env" `
      "--exclude=upload/*" `
      "--exclude=runtime/tools/*.zip" `
      "--exclude=runtime/tools/*.tgz" `
      "."
    if ($LASTEXITCODE -ne 0) {
      throw "archive creation failed."
    }
  } finally {
    Pop-Location
  }

  $item = Get-Item -LiteralPath $outputFull
  Write-Host "Archive ready: $($item.FullName) ($([Math]::Round($item.Length / 1GB, 2)) GB)"
}

Write-Step "Packaging repo: $RepoRoot"
Assert-Directory $RepoRoot "repo root"

. (Join-Path $PSScriptRoot "runtime-download.ps1")

if (-not $KeepServicesRunning) {
  Stop-RuntimeServices
}

Ensure-ImmichRuntime -RepoRoot $RepoRoot -IncludeDatabase
Install-BuildToolsIfNeeded
$python = Ensure-BundledPython
$node = Ensure-BundledNode
Ensure-MachineLearningVenv -PythonExe $python
Build-Web -Node $node
Build-Manager
Preload-Models
Write-RunReadme
Verify-Bundle

if (-not $KeepServicesRunning) {
  Stop-RuntimeServices
}

New-BundleArchive

Write-Host ""
Write-Host "Done." -ForegroundColor Green
