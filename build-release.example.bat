@echo off
chcp 65001 >nul
REM ============================================================
REM 情侣餐记 - 一键编译 release APK（示例文件）
REM
REM 用法：把本文件复制为 build-release.bat，然后填上你的环境 ID。
REM 为什么要复制：build-release.bat 已在 .gitignore 中，
REM 这样你的真实环境 ID 不会被提交到公开仓库。
REM ============================================================

set ENV_ID=请替换为你的云开发环境ID
set REGION=ap-shanghai

cd /d "%~dp0"

call flutter pub get
if errorlevel 1 goto :fail

call flutter build apk --release --dart-define=TCB_ENV_ID=%ENV_ID% --dart-define=TCB_REGION=%REGION%
if errorlevel 1 goto :fail

echo.
echo 编译完成：build\app\outputs\flutter-apk\app-release.apk
pause
exit /b 0

:fail
echo.
echo 编译失败，请查看上面的错误信息。
pause
exit /b 1
