param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$ConfigFile,
  [string]$HostName,
  [int]$Port,
  [string]$MediaLocation,
  [string]$BuildData,
  [int]$PostgresPort,
  [int]$RedisPort,
  [string]$MachineLearningHost = "127.0.0.1",
  [int]$MachineLearningPort = 3003,
  [string]$MachineLearningUrl,
  [string]$MachineLearningCacheFolder,
  [int]$MachineLearningWorkers,
  [switch]$SkipMachineLearning,
  [switch]$SkipWebBuild
)

$ErrorActionPreference = "Stop"
$repoRoot = $RepoRoot

function Import-ImmichEnvFile {
  param([string]$Path)
  if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return
  }

  Get-Content -LiteralPath $Path | ForEach-Object {
    $line = $_.Trim()
    if ((-not $line) -or $line.StartsWith("#")) {
      return
    }
    $index = $line.IndexOf("=")
    if ($index -le 0) {
      return
    }
    $name = $line.Substring(0, $index).Trim()
    $value = $line.Substring($index + 1).Trim().Trim('"')
    if ($name) {
      Set-Item -Path "Env:$name" -Value $value
    }
  }
}

function Set-ImmichEnvOverride {
  param([string]$Name, [object]$Value)
  if ($null -ne $Value -and "$Value" -ne "") {
    Set-Item -Path "Env:$Name" -Value "$Value"
  }
}

if (-not $ConfigFile) {
  $ConfigFile = Join-Path $repoRoot "runtime\immich-windows.env"
}

Import-ImmichEnvFile -Path $ConfigFile

if ($PSBoundParameters.ContainsKey("HostName")) { Set-ImmichEnvOverride "IMMICH_HOST" $HostName }
if ($PSBoundParameters.ContainsKey("Port")) { Set-ImmichEnvOverride "IMMICH_PORT" $Port }
if ($PSBoundParameters.ContainsKey("MediaLocation")) { Set-ImmichEnvOverride "IMMICH_MEDIA_LOCATION" $MediaLocation }
if ($PSBoundParameters.ContainsKey("BuildData")) { Set-ImmichEnvOverride "IMMICH_BUILD_DATA" $BuildData }
if ($PSBoundParameters.ContainsKey("PostgresPort")) { Set-ImmichEnvOverride "IMMICH_POSTGRES_PORT" $PostgresPort }
if ($PSBoundParameters.ContainsKey("RedisPort")) { Set-ImmichEnvOverride "IMMICH_REDIS_PORT" $RedisPort }
if ($PSBoundParameters.ContainsKey("MachineLearningCacheFolder")) { Set-ImmichEnvOverride "MACHINE_LEARNING_CACHE_FOLDER" $MachineLearningCacheFolder }
if ($PSBoundParameters.ContainsKey("MachineLearningWorkers")) { Set-ImmichEnvOverride "MACHINE_LEARNING_WORKERS" $MachineLearningWorkers }
if (-not $MachineLearningUrl) {
  $MachineLearningUrl = "http://${MachineLearningHost}:$MachineLearningPort"
}
if ($PSBoundParameters.ContainsKey("MachineLearningUrl") -or $PSBoundParameters.ContainsKey("MachineLearningHost") -or $PSBoundParameters.ContainsKey("MachineLearningPort")) {
  Set-ImmichEnvOverride "IMMICH_MACHINE_LEARNING_URL" $MachineLearningUrl
}

. (Join-Path $PSScriptRoot "runtime-download.ps1")
Ensure-ImmichRuntime -RepoRoot $repoRoot -IncludeDatabase -IncludeMachineLearning
. (Join-Path $PSScriptRoot "native-env.ps1") -RepoRoot $repoRoot
. (Join-Path $PSScriptRoot "runtime.ps1")
Assert-ImmichLocalRuntime -RepoRoot $repoRoot -RequireDatabase -RequireMachineLearning

if ($env:IMMICH_MACHINE_LEARNING_URL) {
  try {
    $mlUri = [Uri]$env:IMMICH_MACHINE_LEARNING_URL
    if (-not $PSBoundParameters.ContainsKey("MachineLearningHost")) {
      $MachineLearningHost = $mlUri.Host
    }
    if (-not $PSBoundParameters.ContainsKey("MachineLearningPort") -and $mlUri.Port -gt 0) {
      $MachineLearningPort = $mlUri.Port
    }
  } catch {
  }
}

Set-Location $repoRoot

Start-EmbeddedPostgres -RepoRoot $repoRoot
Start-EmbeddedRedis -RepoRoot $repoRoot

if ((-not $SkipWebBuild) -and (-not (Test-Path -LiteralPath (Join-Path $env:IMMICH_BUILD_DATA "www\index.html")))) {
  Write-Host "Web build was not found; building it once..."
  & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "build-web.ps1") -RepoRoot $repoRoot
  if ($LASTEXITCODE -ne 0) {
    throw "Web build failed."
  }
}

if (-not $SkipMachineLearning -and -not (Test-TcpPort -HostName $MachineLearningHost -Port $MachineLearningPort)) {
  Write-Host "Starting machine-learning service..."
  Start-Process -FilePath "powershell" -ArgumentList @(
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $PSScriptRoot "start-ml.ps1"),
    "-RepoRoot", $repoRoot,
    "-HostName", $MachineLearningHost,
    "-Port", "$MachineLearningPort",
    "-ConfigFile", $ConfigFile
  ) -WorkingDirectory $repoRoot -WindowStyle Hidden | Out-Null
}

if (-not $SkipMachineLearning) {
  Wait-TcpPort -Name "Machine learning" -HostName $MachineLearningHost -Port $MachineLearningPort -TimeoutSeconds 120
}

Write-Host ""
Write-Host "Immich native runtime is ready."
Write-Host "Server: http://$env:IMMICH_HOST`:$env:IMMICH_PORT"
Write-Host ""
Write-Host "Starting Immich server..."
$node = Get-ImmichNodeExe -RepoRoot $repoRoot
$pnpm = Get-ImmichPnpmCjs -RepoRoot $repoRoot
if ((-not $node) -or (-not $pnpm)) {
  throw "Bundled Node.js/pnpm was not found and automatic runtime setup did not complete."
}

& $node $pnpm --filter "immich" start:dev
