@echo off
rem Libera RAM de tus programas (sin administrador).
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0Limpiar-Memoria.ps1"
pause
