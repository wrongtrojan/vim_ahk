@echo off
REM =================================================================
REM Build Script for vim_ahk (Verified Scoop V2 Path)
REM Environment: AutoHotkey v2.0
REM =================================================================

SET SCOOP_APPS=D:\Scoop\apps
SET AHK_V2_PATH=%SCOOP_APPS%\AutoHotkey\current\v2
SET COMPILER_EXE=%AHK_V2_PATH%\Compiler\Ahk2Exe.exe

REM --- Pre-flight Check ---
if not exist "%COMPILER_EXE%" (
    echo [ERROR] Compiler not found at: %COMPILER_EXE%
    echo Please verify the path or manually place Ahk2Exe.exe there.
    pause
    exit /b 1
)

SET Param1=%1

REM --- Testing (Optional) ---
if "%Param1%"=="/t" (
  echo [INFO] Running pre-build tests...
  start /w "%AHK_V2_PATH%\AutoHotkey64.exe" tests\run_vimahk_tests.ahk -quiet
  if %errorlevel% neq 0 (
      echo [ERROR] Tests failed. Build aborted.
      exit /b %errorlevel%
  )
)

REM --- Clean & Create Build Directory ---
if exist vim_ahk rmdir /s /q vim_ahk
mkdir vim_ahk

REM --- Compilation ---
echo [INFO] Compiling vim.ahk into standalone executable...
REM /base defines the interpreter used for the compiled EXE (V2 64-bit)
"%COMPILER_EXE%" /in vim.ahk /out vim_ahk\vim_ahk.exe /compress 0 /silent /base "%AHK_V2_PATH%\AutoHotkey64.exe"

if %errorlevel% neq 0 (
  echo [ERROR] Build failed during compilation.
  exit /b %errorlevel%
)

REM --- Asset Injection ---
echo [INFO] Copying icons and resources...
if exist vim_ahk_icons (
    xcopy /i /y vim_ahk_icons vim_ahk\vim_ahk_icons
)

REM --- External Configuration Handling ---
REM Copy existing Config.json if present, ensuring immediate usability.
if exist Config.json (
    copy /y Config.json vim_ahk\Config.json
    echo [INFO] Existing Config.json has been bundled.
) else (
    echo [INFO] No Config.json found. The EXE will generate a default one on first run.
)

echo =================================================================
echo BUILD SUCCESSFUL!
echo Target: %~dp0vim_ahk\vim_ahk.exe
echo =================================================================