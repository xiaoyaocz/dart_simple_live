@echo off
setlocal EnableExtensions

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"

set "APP_DIR=%ROOT_DIR%\simple_live_app"
set "ANDROID_DIR=%APP_DIR%\android"
set "LOCAL_PROPERTIES=%ANDROID_DIR%\local.properties"
set "KEY_PROPERTIES=%ANDROID_DIR%\key.properties"
set "KEY_TEMPLATE=%ANDROID_DIR%\key.properties.example"
set "KEYSTORE_FILE=%ANDROID_DIR%\release-keystore.jks"
set "SDK_DIR=C:\softwares\Android_Sdk"
set "FLUTTER_BIN=C:\softwares\flutter\bin"
set "TARGET_DIR=C:\softwares\SimpleLiveAndroid"
set "APK_PATH=%APP_DIR%\build\app\outputs\flutter-apk\app-release.apk"
set "NO_PAUSE="
set "JDK_DIR="

if /I "%~1"=="--no-pause" set "NO_PAUSE=1"
if not "%~2"=="" set "TARGET_DIR=%~2"
if "%~2"=="" if not "%~1"=="" if /I not "%~1"=="--no-pause" set "TARGET_DIR=%~1"

if not defined JDK_DIR if exist "C:\softwares\jdk-17" set "JDK_DIR=C:\softwares\jdk-17"
if not defined JDK_DIR if exist "C:\softwares\jdk-21" set "JDK_DIR=C:\softwares\jdk-21"
if not defined JDK_DIR if exist "C:\softwares\Android Studio\jbr" set "JDK_DIR=C:\softwares\Android Studio\jbr"
if not defined JDK_DIR if exist "C:\Program Files\Android\Android Studio\jbr" set "JDK_DIR=C:\Program Files\Android\Android Studio\jbr"
if not defined JDK_DIR if exist "C:\Program Files (x86)\Android\Android Studio\jbr" set "JDK_DIR=C:\Program Files (x86)\Android\Android Studio\jbr"
if not defined JDK_DIR if defined JAVA_HOME set "JDK_DIR=%JAVA_HOME%"

title SimpleLive Android APK Build

echo.
echo ==========================================
echo   SimpleLive Android Release APK Builder
echo ==========================================
echo.
echo [INFO] Repo:   %ROOT_DIR%
echo [INFO] App:    %APP_DIR%
echo [INFO] SDK:    %SDK_DIR%
echo [INFO] Target: %TARGET_DIR%
if defined JDK_DIR (
  echo [INFO] JDK:    %JDK_DIR%
) else (
  echo [WARN] JDK:    not detected yet
)
echo.

if not exist "%APP_DIR%\pubspec.yaml" (
  echo [ERROR] Flutter app not found: %APP_DIR%
  goto :fail
)

if not exist "%FLUTTER_BIN%\flutter.bat" (
  echo [ERROR] Flutter not found: %FLUTTER_BIN%\flutter.bat
  goto :fail
)

if not exist "%SDK_DIR%" (
  echo [ERROR] Android SDK not found: %SDK_DIR%
  goto :fail
)

if not defined JDK_DIR (
  echo [ERROR] JDK not found.
  echo [ERROR] Please install JDK 17+ or Android Studio JBR under C:\softwares first.
  echo [ERROR] Then rerun this BAT.
  goto :fail
)

if not exist "%JDK_DIR%\bin\java.exe" (
  echo [ERROR] Invalid JDK path: %JDK_DIR%
  goto :fail
)

if not exist "%JDK_DIR%\bin\keytool.exe" (
  echo [ERROR] keytool.exe not found under: %JDK_DIR%\bin
  echo [ERROR] Please use a full JDK instead of a JRE.
  goto :fail
)

set "JAVA_HOME=%JDK_DIR%"
set "ANDROID_HOME=%SDK_DIR%"
set "ANDROID_SDK_ROOT=%SDK_DIR%"
set "PATH=%FLUTTER_BIN%;%JAVA_HOME%\bin;%ANDROID_HOME%\platform-tools;%ANDROID_HOME%\cmdline-tools\latest\bin;%PATH%"

echo [1/6] Checking Java version...
call java -version
if errorlevel 1 (
  echo [ERROR] Failed to run java from %JAVA_HOME%
  goto :fail
)
echo [ OK ] Java is available.
echo.

echo [2/6] Checking Android local.properties...
if not exist "%LOCAL_PROPERTIES%" (
  > "%LOCAL_PROPERTIES%" echo sdk.dir=C:\\softwares\\Android_Sdk
  >> "%LOCAL_PROPERTIES%" echo flutter.sdk=C:\\softwares\\flutter
  echo [INFO] local.properties created automatically.
) else (
  echo [ OK ] local.properties already exists.
)
echo.

echo [3/6] Checking release signing config...
if not exist "%KEY_PROPERTIES%" (
  echo [ERROR] Missing %KEY_PROPERTIES%
  echo [INFO] Please copy %KEY_TEMPLATE% to key.properties and fill in your own passwords.
  echo [INFO] Keystore file should be placed here:
  echo [INFO] %KEYSTORE_FILE%
  echo [INFO] Example generation command:
  echo [INFO] keytool -genkeypair -v -keystore "%KEYSTORE_FILE%" -alias simplelive_release -keyalg RSA -keysize 2048 -validity 10000
  goto :fail
)
if not exist "%KEYSTORE_FILE%" (
  echo [ERROR] Missing release keystore: %KEYSTORE_FILE%
  echo [INFO] Please generate it first, then rerun this BAT.
  goto :fail
)
echo [ OK ] Release signing files detected.
echo.

echo [4/6] Running flutter pub get...
pushd "%APP_DIR%" || (
  echo [ERROR] Failed to enter app directory.
  goto :fail
)
call flutter pub get
if errorlevel 1 (
  echo [ERROR] flutter pub get failed.
  popd
  goto :fail
)
echo [ OK ] Dependencies are ready.
echo.

echo [5/6] Building release APK...
call flutter build apk --release
if errorlevel 1 (
  echo [ERROR] flutter build apk --release failed.
  echo [INFO] If this is the first Android build on this machine, run:
  echo [INFO] flutter doctor --android-licenses
  popd
  goto :fail
)
echo [ OK ] APK build completed.
echo.

if not exist "%APK_PATH%" (
  echo [ERROR] APK output not found: %APK_PATH%
  popd
  goto :fail
)

echo [6/6] Copying APK to %TARGET_DIR% ...
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"
copy /Y "%APK_PATH%" "%TARGET_DIR%\SimpleLive-release.apk" >nul
if errorlevel 1 (
  echo [ERROR] Failed to copy APK to target directory.
  popd
  goto :fail
)
echo [ OK ] APK copied successfully.
echo.

popd

echo Build finished successfully.
echo [INFO] Output APK:
echo [INFO] %TARGET_DIR%\SimpleLive-release.apk
echo [INFO] Before installing, ask the other side to uninstall the old package first.
echo.
goto :success

:fail
echo.
echo Android APK build failed.
echo.
if not defined NO_PAUSE pause
exit /b 1

:success
if not defined NO_PAUSE pause
exit /b 0
