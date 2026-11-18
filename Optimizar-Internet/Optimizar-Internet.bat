@echo off
rem Renueva la conexion y revisa Wi-Fi, router, internet y DNS (sin administrador).
rem El codigo esta en Optimizar-Internet.ps1 (se puede abrir con el Bloc de notas).
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0Optimizar-Internet.ps1"
echo.
pause
