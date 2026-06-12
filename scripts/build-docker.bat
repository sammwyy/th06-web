@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "REPO_ROOT=%SCRIPT_DIR%.."
set "OUT_DIR=%~1"
set "CONFIG=%~2"

if "%OUT_DIR%"=="" set "OUT_DIR=build/web"
if "%CONFIG%"=="" set "CONFIG=Release"
if "%EMSDK_DOCKER_IMAGE%"=="" set "EMSDK_DOCKER_IMAGE=emscripten/emsdk:latest"

docker info >nul 2>nul
if errorlevel 1 (
    echo Docker is not available or the daemon is not running.
    exit /b 1
)

docker run --rm ^
    -v "%REPO_ROOT%:/src" ^
    -w /src ^
    "%EMSDK_DOCKER_IMAGE%" ^
    bash scripts/build.sh "%OUT_DIR%" "%CONFIG%"

exit /b %ERRORLEVEL%
