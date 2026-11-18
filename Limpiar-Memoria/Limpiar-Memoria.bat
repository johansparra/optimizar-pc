@echo off
rem Libera memoria RAM de tus programas abiertos (sin administrador).
rem El codigo esta en Limpiar-Memoria.ps1 (se puede abrir con el Bloc de notas).
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0Limpiar-Memoria.ps1"
echo.
pause
