@echo off
rem Version simple: borra temporales y caches de tu usuario y revisa el equipo (sin administrador).
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0Optimizar-PC-Simple.ps1"
pause
