$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

. (Join-Path $PSScriptRoot "native-env.ps1") -RepoRoot $repoRoot

Set-Location $repoRoot
corepack pnpm --filter "immich-web" dev --host 127.0.0.1 --port 3000
