@echo off
setlocal
chcp 65001 >nul
title Make Arabic Captions
rem  Portable: copy this one file to any Windows 10/11 PC. The first run installs
rem  everything it needs into %LOCALAPPDATA%\ArabicCaptions (no admin needed).
rem  To remove it later, delete that folder and
rem  %USERPROFILE%\.cache\huggingface\hub\models--Systran--faster-whisper-large-v3

set "APP=%LOCALAPPDATA%\ArabicCaptions"
set "UV=%APP%\uv\uv.exe"
set "PY=%APP%\venv\Scripts\python.exe"
set "STAMP=%APP%\installed-v1.txt"
set "SELF=%~f0"
set "UV_PYTHON_INSTALL_DIR=%APP%\python"
set "UV_PYTHON_PREFERENCE=only-managed"
set "UV_CACHE_DIR=%APP%\cache"
set "UV_NO_CONFIG=1"

if exist "%STAMP%" if exist "%PY%" goto run

echo ==============================================================
echo   First-time setup on this PC (only happens once).
echo   Downloads about 1-2 GB now, and the 3 GB speech model
echo   with the first video. Stay connected to the internet.
echo   If a firewall asks about curl, uv or python, allow it.
echo ==============================================================
echo.
if not exist "%APP%" mkdir "%APP%"
if exist "%UV%" goto have_uv
echo [1/3] Downloading the installer...
set "UVURL=https://github.com/astral-sh/uv/releases/download/0.12.2/uv-x86_64-pc-windows-msvc.zip"
curl.exe -L --fail --retry 3 -o "%APP%\uv.zip" "%UVURL%"
if not errorlevel 1 goto unzip_uv
echo       curl did not work, trying PowerShell...
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol='Tls12'; Invoke-WebRequest -UseBasicParsing $env:UVURL -OutFile (Join-Path $env:APP 'uv.zip')"
if errorlevel 1 goto fail
:unzip_uv
if not exist "%APP%\uv" mkdir "%APP%\uv"
tar -xf "%APP%\uv.zip" -C "%APP%\uv"
if errorlevel 1 goto fail
del "%APP%\uv.zip"
:have_uv
echo [2/3] Installing Python and the speech libraries...
set "BASEPY=%APP%\python\cpython-3.13.14-windows-x86_64-none\python.exe"
if not exist "%BASEPY%" "%UV%" python install 3.13.14 --no-bin
if not exist "%BASEPY%" goto fail
"%UV%" venv --python "%BASEPY%" --allow-existing "%APP%\venv"
if errorlevel 1 goto fail
"%UV%" pip install --python "%PY%" faster-whisper==1.2.1 ctranslate2==4.8.4 av==19.0.2
if errorlevel 1 goto fail
where nvidia-smi >nul 2>nul
if errorlevel 1 goto no_gpu
echo [3/3] NVIDIA graphics card found, installing its speed-up libraries...
"%UV%" pip install --python "%PY%" nvidia-cublas-cu12==12.9.2.10 nvidia-cudnn-cu12==9.27.0.42
if errorlevel 1 echo       Could not install them. Captions will use the processor instead.
goto setup_done
:no_gpu
echo [3/3] No NVIDIA graphics card. Captions will use the processor (slower).
:setup_done
echo installed> "%STAMP%"
echo.
echo Setup finished.
echo.

:run
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t=[IO.File]::ReadAllText($env:SELF); $m='#=='+'PYTHON==#'; $i=$t.LastIndexOf($m); [IO.File]::WriteAllText((Join-Path $env:APP 'make_captions.py'), $t.Substring($i+$m.Length).TrimStart(), (New-Object Text.UTF8Encoding $false))"
if errorlevel 1 goto fail
"%PY%" "%APP%\make_captions.py" %*
echo.
pause
exit /b

:fail
echo.
echo Setup did not finish. Check the internet connection (and allow any
echo firewall pop-up), then run this file again. It continues where it stopped.
echo.
pause
exit /b 1

