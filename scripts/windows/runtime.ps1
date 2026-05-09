function Test-TcpPort {
  param(
    [Parameter(Mandatory = $true)][string]$HostName,
    [Parameter(Mandatory = $true)][int]$Port
  )

  $client = [System.Net.Sockets.TcpClient]::new()
  try {
    $task = $client.ConnectAsync($HostName, $Port)
    return $task.Wait(500)
  } catch {
    return $false
  } finally {
    $client.Dispose()
  }
}

function Wait-TcpPort {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$HostName,
    [Parameter(Mandatory = $true)][int]$Port,
    [int]$TimeoutSeconds = 45
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    if (Test-TcpPort -HostName $HostName -Port $Port) {
      return
    }
    Start-Sleep -Milliseconds 500
  }

  throw "$Name did not become ready at ${HostName}:${Port} within ${TimeoutSeconds}s"
}

function Wait-PostgresReady {
  param(
    [Parameter(Mandatory = $true)][string]$PgIsReadyExe,
    [Parameter(Mandatory = $true)][int]$Port,
    [int]$TimeoutSeconds = 90
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    & $PgIsReadyExe -h 127.0.0.1 -p $Port -U postgres -d postgres | Out-Null
    if ($LASTEXITCODE -eq 0) {
      return
    }
    Start-Sleep -Milliseconds 500
  }

  throw "PostgreSQL accepted TCP connections but did not become query-ready within ${TimeoutSeconds}s"
}

function Assert-File {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Message
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "$Message`nMissing: $Path"
  }
}

function Convert-ToRedisRuntimePath {
  param([Parameter(Mandatory = $true)][string]$Path)

  $full = [System.IO.Path]::GetFullPath($Path).Replace("\", "/")
  if ($full -match "^([A-Za-z]):/(.*)$") {
    return "/cygdrive/$($matches[1].ToLower())/$($matches[2])"
  }
  return $full
}

function Start-EmbeddedPostgres {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $bin = $env:IMMICH_POSTGRES_BIN
  $data = $env:IMMICH_POSTGRES_DATA
  $port = [int]$env:IMMICH_POSTGRES_PORT
  $logDir = Join-Path $RepoRoot "runtime\logs"
  $logFile = Join-Path $logDir "postgres.log"

  New-Item -ItemType Directory -Force -Path $data, $logDir | Out-Null

  $postgresExe = Join-Path $bin "postgres.exe"
  $pgCtlExe = Join-Path $bin "pg_ctl.exe"
  $initDbExe = Join-Path $bin "initdb.exe"
  $psqlExe = Join-Path $bin "psql.exe"
  $createdbExe = Join-Path $bin "createdb.exe"
  $pgIsReadyExe = Join-Path $bin "pg_isready.exe"
  $vectorControl = Join-Path (Split-Path $bin -Parent) "share\extension\vector.control"

  Assert-File $postgresExe "Embedded PostgreSQL runtime is not integrated into this project."
  Assert-File $pgCtlExe "Embedded PostgreSQL runtime is incomplete."
  Assert-File $initDbExe "Embedded PostgreSQL runtime is incomplete."
  Assert-File $psqlExe "Embedded PostgreSQL runtime is incomplete."
  Assert-File $createdbExe "Embedded PostgreSQL runtime is incomplete."
  Assert-File $pgIsReadyExe "Embedded PostgreSQL runtime is incomplete."
  Assert-File $vectorControl "Embedded pgvector extension is not integrated into PostgreSQL."

  if (-not (Test-Path -LiteralPath (Join-Path $data "PG_VERSION"))) {
    Write-Host "Initializing embedded PostgreSQL data directory..."
    & $initDbExe -D $data -U postgres --encoding=UTF8 --locale=C | Out-Host
    if ($LASTEXITCODE -ne 0) {
      throw "PostgreSQL initdb failed."
    }
  }

  if (-not (Test-TcpPort -HostName "127.0.0.1" -Port $port)) {
    $postmasterPid = Join-Path $data "postmaster.pid"
    if (Test-Path -LiteralPath $postmasterPid -PathType Leaf) {
      $pidLine = Get-Content -LiteralPath $postmasterPid -TotalCount 1 -ErrorAction SilentlyContinue
      $postgresPid = 0
      if ([int]::TryParse($pidLine, [ref]$postgresPid) -and -not (Get-Process -Id $postgresPid -ErrorAction SilentlyContinue)) {
        Remove-Item -LiteralPath $postmasterPid -Force -ErrorAction SilentlyContinue
      }
    }

    Write-Host "Starting embedded PostgreSQL on 127.0.0.1:$port..."
    $pgArgs = "-D `"$data`" -l `"$logFile`" -o `"-h 127.0.0.1 -p $port`" start"
    Start-Process -FilePath $pgCtlExe -ArgumentList $pgArgs -WindowStyle Hidden | Out-Null
  }

  Wait-TcpPort -Name "PostgreSQL" -HostName "127.0.0.1" -Port $port
  Wait-PostgresReady -PgIsReadyExe $pgIsReadyExe -Port $port

  $env:PGPASSWORD = "postgres"
  $databaseExists = & $psqlExe -h 127.0.0.1 -p $port -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = 'immich';"
  if ($LASTEXITCODE -ne 0) {
    throw "Could not check the embedded PostgreSQL database."
  }

  if (-not ($databaseExists -contains "1")) {
    & $createdbExe -h 127.0.0.1 -p $port -U postgres immich 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) {
      throw "Could not create the embedded PostgreSQL database."
    }
  }

  & $psqlExe -h 127.0.0.1 -p $port -U postgres -d immich -v ON_ERROR_STOP=1 -c "SET client_min_messages TO warning; CREATE EXTENSION IF NOT EXISTS vector;" | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "Could not enable pgvector in the embedded PostgreSQL database."
  }
}

function Start-EmbeddedRedis {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $bin = $env:IMMICH_REDIS_BIN
  $data = $env:IMMICH_REDIS_DATA
  $port = [int]$env:IMMICH_REDIS_PORT
  $logDir = Join-Path $RepoRoot "runtime\logs"
  $logFile = Join-Path $logDir "redis.log"
  $configFile = Join-Path $data "redis.conf"

  New-Item -ItemType Directory -Force -Path $data, $logDir | Out-Null

  $redisExe = Join-Path $bin "redis-server.exe"
  Assert-File $redisExe "Embedded Redis-compatible runtime is not integrated into this project."

  if (-not (Test-TcpPort -HostName "127.0.0.1" -Port $port)) {
    Write-Host "Starting embedded Redis on 127.0.0.1:$port..."
    $redisData = $data -replace "\\", "/"
    $redisLog = $logFile -replace "\\", "/"
    $redisConfig = Convert-ToRedisRuntimePath -Path $configFile
    @(
      "bind 127.0.0.1",
      "port $port",
      "dir `"$redisData`"",
      "logfile `"$redisLog`"",
      "save `"`""
    ) | Set-Content -LiteralPath $configFile -Encoding ASCII
    Start-Process -FilePath $redisExe -ArgumentList @($redisConfig) -WindowStyle Hidden | Out-Null
  }

  Wait-TcpPort -Name "Redis" -HostName "127.0.0.1" -Port $port
}
