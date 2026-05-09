param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"
$repoRoot = $RepoRoot

. (Join-Path $PSScriptRoot "runtime-download.ps1")
Ensure-ImmichRuntime -RepoRoot $repoRoot
. (Join-Path $PSScriptRoot "native-env.ps1") -RepoRoot $repoRoot
Assert-ImmichLocalRuntime -RepoRoot $repoRoot

Set-Location $repoRoot

$webBuild = Join-Path $repoRoot "web\build"
$svelteOutput = Join-Path $repoRoot "web\.svelte-kit\output"
foreach ($path in @($webBuild, $svelteOutput)) {
  if (Test-Path $path) {
    Remove-Item -LiteralPath $path -Recurse -Force
  }
}

if (-not $env:IMMICH_BUILD) {
  $env:IMMICH_BUILD = "windows-" + (Get-Date -Format "yyyyMMddHHmmss")
}

$node = Get-ImmichNodeExe -RepoRoot $repoRoot
$pnpm = Get-ImmichPnpmCjs -RepoRoot $repoRoot
if ((-not $node) -or (-not $pnpm)) {
  throw "Bundled Node.js/pnpm was not found and automatic runtime setup did not complete."
}

& $node $pnpm --filter "@immich/sdk" --filter "immich-web" build
if ($LASTEXITCODE -ne 0) {
  throw "Web build failed."
}

$target = Join-Path $env:IMMICH_BUILD_DATA "www"
if (Test-Path $target) {
  Remove-Item -LiteralPath $target -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $target | Out-Null
Copy-Item -Path (Join-Path $repoRoot "web\build\*") -Destination $target -Recurse -Force

$corePlugin = Join-Path $env:IMMICH_BUILD_DATA "corePlugin"
New-Item -ItemType Directory -Force -Path $corePlugin | Out-Null
Copy-Item -LiteralPath (Join-Path $repoRoot "plugins\manifest.json") -Destination (Join-Path $corePlugin "manifest.json") -Force
if (Test-Path (Join-Path $repoRoot "plugins\dist")) {
  Copy-Item -LiteralPath (Join-Path $repoRoot "plugins\dist") -Destination $corePlugin -Recurse -Force
}

Write-Host "Web assets copied to $target"
