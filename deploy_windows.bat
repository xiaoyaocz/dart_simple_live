@echo off
setlocal EnableExtensions

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"

set "APP_DIR=%ROOT_DIR%\simple_live_app"
set "BUILD_DIR=%APP_DIR%\build\windows\x64\runner\Release"
set "TARGET_DIR=C:\softwares\SimpleLive"
set "FLUTTER_BIN=C:\softwares\flutter\bin"
set "NUGET_DIR=C:\softwares\nuget"
set "NO_PAUSE="

if /I "%~1"=="--no-pause" set "NO_PAUSE=1"
if not "%~2"=="" set "TARGET_DIR=%~2"
if "%~2"=="" if not "%~1"=="" if /I not "%~1"=="--no-pause" set "TARGET_DIR=%~1"

title SimpleLive Windows Deploy

echo.
echo ==========================================
echo   SimpleLive Windows Auto Deploy Script
echo ==========================================
echo.
echo [INFO] Repo:   %ROOT_DIR%
echo [INFO] App:    %APP_DIR%
echo [INFO] Target: %TARGET_DIR%
echo.

if not exist "%APP_DIR%\pubspec.yaml" (
  echo [ERROR] Flutter app not found: %APP_DIR%
  goto :fail
)

if not exist "%FLUTTER_BIN%\flutter.bat" (
  echo [ERROR] Flutter not found: %FLUTTER_BIN%\flutter.bat
  goto :fail
)

if not exist "%NUGET_DIR%\nuget.exe" (
  echo [ERROR] NuGet not found: %NUGET_DIR%\nuget.exe
  echo [ERROR] Please make sure NuGet is installed under C:\softwares\nuget
  goto :fail
)

set "PATH=%FLUTTER_BIN%;%NUGET_DIR%;%PATH%"

echo [1/5] Checking whether SimpleLive is still running...
tasklist /FI "IMAGENAME eq simple_live_app.exe" 2>nul | find /I "simple_live_app.exe" >nul
if not errorlevel 1 (
  echo [INFO] simple_live_app.exe is running. Stopping it now...
  taskkill /IM simple_live_app.exe /F >nul 2>&1
  if errorlevel 1 (
    echo [ERROR] Failed to stop simple_live_app.exe automatically.
    echo [ERROR] Please close it manually, then run this BAT again.
    goto :fail
  )
  ping 127.0.0.1 -n 3 >nul
  echo [ OK ] Existing process stopped.
  echo.
)
echo [ OK ] No running SimpleLive process found.
echo.

pushd "%APP_DIR%" || (
  echo [ERROR] Failed to enter app directory.
  goto :fail
)

echo [2/5] Running flutter pub get...
call flutter pub get
if errorlevel 1 (
  echo [ERROR] flutter pub get failed.
  popd
  goto :fail
)
echo [ OK ] Dependencies are ready.
echo.

echo [3/5] Building Windows release...
call flutter build windows --release
if errorlevel 1 (
  echo [ERROR] flutter build windows --release failed.
  popd
  goto :fail
)
echo [ OK ] Build completed.
echo.

if not exist "%BUILD_DIR%\simple_live_app.exe" (
  echo [ERROR] Build output not found: %BUILD_DIR%\simple_live_app.exe
  popd
  goto :fail
)

echo [4/5] Deploying files to %TARGET_DIR% ...
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"
robocopy "%BUILD_DIR%" "%TARGET_DIR%" /MIR /R:2 /W:1 /NFL /NDL /NJH /NJS /NP >nul
set "ROBOCOPY_EXIT=%ERRORLEVEL%"
if %ROBOCOPY_EXIT% GEQ 8 (
  echo [ERROR] Robocopy failed with exit code %ROBOCOPY_EXIT%.
  popd
  goto :fail
)
echo [ OK ] Files deployed.
echo.

popd

echo [5/5] Done.
echo [INFO] You can now run:
echo [INFO] %TARGET_DIR%\simple_live_app.exe
echo.
goto :success

:fail
echo.
echo Deployment failed.
echo.
if not defined NO_PAUSE pause
exit /b 1

:success
echo Deployment finished successfully.
echo.
if not defined NO_PAUSE pause
exit /b 0
