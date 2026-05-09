param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$ConfigFile,
  [string]$HostName = "127.0.0.1",
  [int]$Port = 3003
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

if (-not $ConfigFile) {
  $ConfigFile = Join-Path $repoRoot "runtime\immich-windows.env"
}
Import-ImmichEnvFile -Path $ConfigFile

. (Join-Path $PSScriptRoot "runtime-download.ps1")
Ensure-ImmichRuntime -RepoRoot $repoRoot -IncludeMachineLearning
. (Join-Path $PSScriptRoot "native-env.ps1") -RepoRoot $repoRoot
Assert-ImmichLocalRuntime -RepoRoot $repoRoot -RequireMachineLearning

$env:IMMICH_HOST = $HostName
$env:IMMICH_PORT = "$Port"
$env:PORT = "$Port"
$env:MACHINE_LEARNING_HOST = $HostName
$env:MACHINE_LEARNING_PORT = "$Port"

Set-Location (Join-Path $repoRoot "machine-learning")
$venvPython = Join-Path $repoRoot "machine-learning\.venv\Scripts\python.exe"
if (-not (Test-Path -LiteralPath $venvPython -PathType Leaf)) {
  throw "Machine-learning venv was not found and automatic runtime setup did not complete."
}

& $venvPython -m immich_ml --host $HostName --port $Port
