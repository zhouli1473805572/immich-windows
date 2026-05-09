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

$argsList = @(
  "-ExecutionPolicy", "Bypass",
  "-File", (Join-Path $PSScriptRoot "package-bundle.ps1"),
  "-RepoRoot", $RepoRoot
)

if ($OutputZip) { $argsList += @("-OutputZip", $OutputZip) }
if ($SkipBuildToolsInstall) { $argsList += "-SkipBuildToolsInstall" }
if ($SkipWebBuild) { $argsList += "-SkipWebBuild" }
if ($SkipModelPreload) { $argsList += "-SkipModelPreload" }
if ($KeepServicesRunning) { $argsList += "-KeepServicesRunning" }
if ($KeepLocalData) { $argsList += "-KeepLocalData" }
if ($KeepLocalConfig) { $argsList += "-KeepLocalConfig" }
if ($NoArchive) { $argsList += "-NoArchive" }

& powershell @argsList
exit $LASTEXITCODE
