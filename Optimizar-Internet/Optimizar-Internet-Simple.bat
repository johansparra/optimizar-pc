@echo off
rem Version simple: renueva la IP (si no hay VPN) y revisa la conexion (sin administrador).
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0Optimizar-Internet-Simple.ps1"
pause
