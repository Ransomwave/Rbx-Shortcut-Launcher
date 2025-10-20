@echo off
REM Batch file to run the Roblox Shortcut Updater

REM Run the PowerShell script
powershell.exe -ExecutionPolicy Bypass -File "%~dp0src\UpdateShortcut.ps1"

REM Pause to see output
pause