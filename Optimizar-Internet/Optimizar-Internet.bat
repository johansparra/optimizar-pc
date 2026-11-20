@echo off
rem Renueva la IP (si no hay VPN) y revisa la conexion (sin administrador).
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0Optimizar-Internet.ps1"
pause
