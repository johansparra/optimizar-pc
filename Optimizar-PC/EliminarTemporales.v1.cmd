color 0A
title Limpieza de temporales - Windows 11

echo DISM — limpieza del almacén de componentes de Windows (WinSxS)
Dism.exe /online /Cleanup-Image /StartComponentCleanup

echo tanto para NTFS como para ReFS — TRIM
::fsutil behavior query DisableDeleteNotify
fsutil behavior set DisableDeleteNotify 0

echo Desfragmentando
defrag C: /O
defrag D: /O

@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "SCRIPT_DIR=%~dp0"

echo Iniciando...
call :DelMode "%TEMP%" 2
call :DelMode "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Cache" 2
call :DelMode "%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Recent" 2
call :DelMode "%USERPROFILE%\AppData\Local\CrashDumps" 2
call :DelMode "%USERPROFILE%\AppData\Local\Microsoft\Windows\WER\ReportQueue" 2
call :DelMode "%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Cookies" 2
call :DelMode "%LOCALAPPDATA%\Microsoft\Windows\History" 2
call :DelMode "%LOCALAPPDATA%\Microsoft\Windows\Explorer" 1 "*.db"
call :DelMode "%LOCALAPPDATA%\Microsoft\Windows\WebCache" 1 "*.log"
call :DelMode "%LOCALAPPDATA%\Microsoft\Windows\InetCache" 2
Echo Limpiando papelera
powershell -NoProfile -ExecutionPolicy Bypass -Command "Clear-RecycleBin -Force" >nul 2>nul

@echo off
::cleanmgr /sageset:1
cleanmgr /sagerun:1
::echo Analizando Virus.
::mrt.exe /Q

echo Finalizado.


pause
exit /b


:DelMode
set "dir=%~1"
set "mode=%~2"
set "pattern=%~3"

if not defined pattern set "pattern=*.*"
if /I "%mode%"=="FULL" set "mode=2"
if /I "%mode%"=="NORMAL" set "mode=1"


if not exist "%dir%\" (
  echo [SKIP] No existe: "%dir%"
  goto :eof
)

set "dir2=%dir%"
if not "%dir2:~-1%"=="\" set "dir2=%dir2%\"

echo [DEL-%mode%] "%dir2%%pattern%"

if "%mode%"=="2" (
  del /S /F /Q /A "%dir2%%pattern%" 2>nul
) else (
  del /S /F /Q    "%dir2%%pattern%" 2>nul
)

if "%mode%"=="2" (
  echo [RD-2] Eliminando subcarpetas en "%dir2%"
  for /d %%G in ("%dir2%*") do rd /s /q "%%~G" 2>nul
)


goto :eof