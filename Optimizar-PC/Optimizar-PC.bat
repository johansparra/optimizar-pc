@echo off
rem Borra temporales y caches de tu usuario y revisa el equipo (sin administrador).
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0Optimizar-PC.ps1"
pause
