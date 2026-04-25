@echo off
setlocal

REM --- Verzeichnis der CMD ermitteln ---
set "SCRIPT_DIR=%~dp0"

REM --- PowerShell-Skript ausführen und warten ---
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%PowerEdge.ps1"
REM Alternativ mit -Wait, falls Start-Process genutzt würde

REM echo.
REM echo Press any key to exit...
REM pause >nul

endlocal
exit /b
