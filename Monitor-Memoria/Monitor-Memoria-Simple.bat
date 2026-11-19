@echo off
rem Version simple: % de RAM junto al reloj. Deja una ventana minimizada: no la cierres.
rem Para cerrar el monitor: clic derecho en el icono > Salir.
start "Monitor de memoria" /min powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0Monitor-Memoria-Simple.ps1"
