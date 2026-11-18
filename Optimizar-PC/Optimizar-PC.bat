@echo off
rem Limpia temporales y caches de tu usuario y revisa el equipo (sin administrador).
rem El codigo esta en Optimizar-PC.ps1 (se puede abrir con el Bloc de notas).
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0Optimizar-PC.ps1"
echo.
pause
