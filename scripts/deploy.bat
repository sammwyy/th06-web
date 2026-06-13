@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "REPO_ROOT=%SCRIPT_DIR%.."
set "OUT_DIR=%OUT_DIR%"
set "CONFIG=%CONFIG%"
set "REMOTE=%DEPLOY_REMOTE%"
set "BRANCH=%DEPLOY_BRANCH%"
set "WORKTREE=%DEPLOY_WORKTREE%"
set "MESSAGE=%DEPLOY_MESSAGE%"
set "BUILD_FIRST=0"

if "%OUT_DIR%"=="" set "OUT_DIR=build\web"
if "%CONFIG%"=="" set "CONFIG=Release"
if "%REMOTE%"=="" set "REMOTE=origin"
if "%BRANCH%"=="" set "BRANCH=gh-pages"
if "%WORKTREE%"=="" set "WORKTREE=%REPO_ROOT%\build\gh-pages-worktree"
if "%MESSAGE%"=="" set "MESSAGE=Deploy browser build"

:parse_args
if "%~1"=="" goto after_args
if "%~1"=="--build" (
    set "BUILD_FIRST=1"
    shift
    goto parse_args
)
if "%~1"=="--skip-build" (
    set "BUILD_FIRST=0"
    shift
    goto parse_args
)
if "%~1"=="-h" goto usage
if "%~1"=="--help" goto usage
echo Unknown argument: %~1
exit /b 2

:usage
echo Usage: scripts\deploy.bat [--build] [--skip-build]
echo Deploys build\web to gh-pages.
exit /b 0

:after_args
cd /d "%REPO_ROOT%" || exit /b 1

if "%BUILD_FIRST%"=="1" (
    call "%SCRIPT_DIR%build-docker.bat" "%OUT_DIR%" "%CONFIG%"
    if errorlevel 1 exit /b 1
)

for %%F in (index.html index.js index.wasm logo.png NotoSansJP-Regular.ttf) do (
    if not exist "%OUT_DIR%\%%F" (
        echo Missing deploy artifact: %OUT_DIR%\%%F
        exit /b 1
    )
)

if exist "%WORKTREE%" (
    echo Deploy worktree already exists: %WORKTREE%
    echo Remove it or set DEPLOY_WORKTREE to another path.
    exit /b 1
)

git ls-remote --exit-code --heads "%REMOTE%" "%BRANCH%" >nul 2>nul
if not errorlevel 1 (
    git fetch "%REMOTE%" "%BRANCH%" || goto fail
    git worktree add -B "%BRANCH%" "%WORKTREE%" FETCH_HEAD || goto fail
) else (
    git show-ref --verify --quiet "refs/heads/%BRANCH%" >nul 2>nul
    if not errorlevel 1 (
        git worktree add -B "%BRANCH%" "%WORKTREE%" "%BRANCH%" || goto fail
    ) else (
        git worktree add --detach "%WORKTREE%" HEAD || goto fail
        git -C "%WORKTREE%" switch --orphan "%BRANCH%" || goto fail
    )
)

git -C "%WORKTREE%" rm -r --ignore-unmatch . >nul 2>nul
git -C "%WORKTREE%" clean -fdx >nul 2>nul

copy /Y "%OUT_DIR%\index.html" "%WORKTREE%\index.html" >nul || goto fail
copy /Y "%OUT_DIR%\index.js" "%WORKTREE%\index.js" >nul || goto fail
copy /Y "%OUT_DIR%\index.wasm" "%WORKTREE%\index.wasm" >nul || goto fail
copy /Y "%OUT_DIR%\logo.png" "%WORKTREE%\logo.png" >nul || goto fail
copy /Y "%OUT_DIR%\NotoSansJP-Regular.ttf" "%WORKTREE%\NotoSansJP-Regular.ttf" >nul || goto fail
type nul > "%WORKTREE%\.nojekyll"

git -C "%WORKTREE%" add -A || goto fail
git -C "%WORKTREE%" diff --cached --quiet
if not errorlevel 1 (
    echo No changes to deploy.
    goto cleanup_ok
)

git -C "%WORKTREE%" commit -m "%MESSAGE%" || goto fail
git -C "%WORKTREE%" push "%REMOTE%" "%BRANCH%" || goto fail

echo Deployed %OUT_DIR% to %REMOTE%/%BRANCH%
goto cleanup_ok

:fail
set "STATUS=1"
goto cleanup

:cleanup_ok
set "STATUS=0"

:cleanup
if not "%KEEP_DEPLOY_WORKTREE%"=="1" (
    if exist "%WORKTREE%" git worktree remove --force "%WORKTREE%" >nul 2>nul
)
exit /b %STATUS%
