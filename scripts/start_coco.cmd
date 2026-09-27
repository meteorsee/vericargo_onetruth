@echo off
setlocal

set "CORTEX_LAUNCHER=%LOCALAPPDATA%\cortex\bin\cortex.cmd"
set "PROJECT_ROOT=%~dp0.."

if not exist "%CORTEX_LAUNCHER%" (
  echo CoCo CLI was not found at "%CORTEX_LAUNCHER%".
  echo Install CoCo using Snowflake's official Windows installer.
  exit /b 1
)

if /I "%~1"=="--check" (
  call "%CORTEX_LAUNCHER%" --version
  exit /b %ERRORLEVEL%
)

if "%~1"=="" (
  echo No connection supplied. CoCo will open its connection picker/setup wizard.
  call "%CORTEX_LAUNCHER%" -w "%PROJECT_ROOT%" --plan
) else (
  call "%CORTEX_LAUNCHER%" -w "%PROJECT_ROOT%" -c "%~1" --plan
)

exit /b %ERRORLEVEL%
