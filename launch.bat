@echo off
setlocal
cd /d "%~dp0"
set "VENV=.venv"

rem Already set up for this requirements.txt? Start silently.
if exist "%VENV%\Scripts\pythonw.exe" (
  fc /b requirements.txt "%VENV%\.installed" >nul 2>nul && goto run
)

echo FocusStart: first-time setup. This takes a minute or two...
echo.

set "PY="
where py >nul 2>nul && py -3.12 -c "import sys" >nul 2>nul && set "PY=py -3.12"
if not defined PY (
  where python >nul 2>nul && python -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)" >nul 2>nul && set "PY=python"
)
if not defined PY (
  echo Couldn't find Python 3.10 or newer ^(tried "py -3.12" and "python"^).
  echo Install Python 3.12, then run launch.bat again.
  echo.
  pause
  exit /b 1
)
echo Using: %PY%

if not exist "%VENV%\Scripts\python.exe" (
  %PY% -m venv "%VENV%" || goto fail
)
"%VENV%\Scripts\python.exe" -m pip install --upgrade pip || goto fail
"%VENV%\Scripts\python.exe" -m pip install -r requirements.txt || goto fail
"%VENV%\Scripts\python.exe" -c "import PySide6.QtQuick, PySide6.QtQuickControls2, PySide6.QtMultimedia" || goto loadfail
copy /y requirements.txt "%VENV%\.installed" >nul

:run
start "" "%VENV%\Scripts\pythonw.exe" -m app %*
exit /b 0

:loadfail
echo.
echo PySide6 installed, but Windows couldn't load its Qt files.
echo Delete the .venv folder next to launch.bat and run launch.bat again.
echo.
pause
exit /b 1

:fail
echo.
echo Setup didn't finish. Check your internet connection and run launch.bat again.
echo If it keeps failing, delete the .venv folder next to launch.bat and try once more.
echo.
pause
exit /b 1
