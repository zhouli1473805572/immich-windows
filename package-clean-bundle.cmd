@echo off
setlocal
title Immich Windows Bundle Packager

cd /d "%~dp0"

echo ============================================================
echo Immich Windows clean bundle packager
echo ============================================================
echo.
echo Working directory:
echo   %CD%
echo.
echo This command will create a clean zip package.
echo Before archiving, package-clean-bundle.ps1 will clear local
echo runtime data from the package workspace:
echo   runtime\data
echo   runtime\logs
echo   upload
echo   runtime\hf-home
echo   .cache\immich_ml
echo.
echo Progress will be printed below.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\windows\package-clean-bundle.ps1"

set "EXITCODE=%ERRORLEVEL%"
echo.
echo ============================================================
if "%EXITCODE%"=="0" (
  echo Packaging completed successfully.
) else (
  echo Packaging failed. Exit code: %EXITCODE%
)
echo ============================================================
echo.
pause
exit /b %EXITCODE%
