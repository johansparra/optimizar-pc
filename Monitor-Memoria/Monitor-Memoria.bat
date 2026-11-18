@echo off
rem Muestra el % de memoria RAM junto al reloj (sin administrador).
rem Deja una ventana minimizada "Monitor de memoria" en la barra de tareas: no la cierres.
rem Para cerrar el monitor: clic derecho en el icono > Salir.
rem El codigo esta en Monitor-Memoria.ps1 (se puede abrir con el Bloc de notas).
start "Monitor de memoria" /min powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0Monitor-Memoria.ps1"
