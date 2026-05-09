param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$ConfigFile,
  [string]$HostName,
  [int]$Port,
  [string]$MediaLocation,
  [string]$BuildData,
  [int]$PostgresPort,
  [int]$RedisPort,
  [string]$MachineLearningUrl
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
if ($PSBoundParameters.ContainsKey("MachineLearningUrl")) { Set-ImmichEnvOverride "IMMICH_MACHINE_LEARNING_URL" $MachineLearningUrl }

. (Join-Path $PSScriptRoot "runtime-download.ps1")
Ensure-ImmichRuntime -RepoRoot $repoRoot -IncludeDatabase
. (Join-Path $PSScriptRoot "native-env.ps1") -RepoRoot $repoRoot
. (Join-Path $PSScriptRoot "runtime.ps1")
Assert-ImmichLocalRuntime -RepoRoot $repoRoot -RequireDatabase

Set-Location $repoRoot
Start-EmbeddedPostgres -RepoRoot $repoRoot
Start-EmbeddedRedis -RepoRoot $repoRoot

$node = Get-ImmichNodeExe -RepoRoot $repoRoot
$pnpm = Get-ImmichPnpmCjs -RepoRoot $repoRoot
if ((-not $node) -or (-not $pnpm)) {
  throw "Bundled Node.js/pnpm was not found and automatic runtime setup did not complete."
}

& $node $pnpm --filter "immich" start:dev
