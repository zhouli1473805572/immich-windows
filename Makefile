start:
	powershell -ExecutionPolicy Bypass -File ./scripts/windows/start-all.ps1

build-web:
	powershell -ExecutionPolicy Bypass -File ./scripts/windows/build-web.ps1

start-server:
	powershell -ExecutionPolicy Bypass -File ./scripts/windows/start-server-dev.ps1

start-web:
	powershell -ExecutionPolicy Bypass -File ./scripts/windows/start-web-dev.ps1

start-ml:
	powershell -ExecutionPolicy Bypass -File ./scripts/windows/start-ml.ps1

check:
	corepack pnpm --filter immich run check
	corepack pnpm --filter @immich/sdk build
	corepack pnpm --filter immich-web run check:typescript
