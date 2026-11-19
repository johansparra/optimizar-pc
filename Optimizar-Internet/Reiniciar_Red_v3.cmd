@ECHO OFF
color 0A
TITLE Optimizacion de Red - Gaming Stable v3
echo ================================================================
echo.
:: echo REQUEIRE REINICIO NO USAR
::echo [release]
::ipconfig /release
::echo [renew]
::ipconfig /renew
echo [PASO 1/8] FASE 1: 
netsh advfirewall reset
netsh branchcache reset
netsh http flush logbuffer
timeout /t 5 /nobreak
netsh int ipv4 reset
timeout /t 5 /nobreak
echo.

echo [PASO 2/8] Renovando IP ANTES del reset (mientras el stack aun esta sano)...

echo [flushdns]
ipconfig /flushdns
echo   -^> Listo.
echo.

echo [PASO 3/8] Limpiando cache NetBIOS y ARP...
nbtstat -R
nbtstat -RR
arp -d *
echo   -^> Listo.
echo.

echo [PASO 4/8] Reiniciando Winsock...
netsh winsock reset
echo   -^> Listo.
echo.

echo [PASO 5/8] Reiniciando configuracion IP...
netsh int ip reset
echo   -^> Listo.
echo.

echo [PASO 6/8] Restableciendo configuracion de proxy...
netsh winhttp reset proxy
echo   -^> Listo.
echo.

echo [FASE 2 - PASO 2/6] Ajustando parametros TCP (el stack ya esta limpio)...
netsh int tcp set heuristics disabled
netsh int tcp set global autotuninglevel=normal
netsh int tcp set global rss=enabled
netsh int tcp set global rsc=disabled
netsh int tcp set supplemental Internet congestionprovider=ctcp
netsh int tcp set global timestamps=disabled
netsh int tcp set global ecncapability=disabled
netsh int tcp set global initialrto=2000
netsh int tcp set global maxsynretransmissions=2
echo   -^> Listo.
echo.

echo [FASE 2 - PASO 3/6] Desactivando Teredo (IPv6 tunneling)...
netsh interface teredo set state disabled
echo   -^> Listo.
echo.

echo [FASE 2 - PASO 4/6] Configurando DNS Google en el adaptador Ethernet...
netsh interface ip set dns name="Ethernet" static 8.8.8.8
netsh interface ip add dns name="Ethernet" 8.8.4.4 index=2
echo   -^> Listo.
echo.

echo [FASE 2 - PASO 5/6] Verificando servicios de red...
sc query dhcp | find "RUNNING" >nul
if errorlevel 1 (
    echo   Iniciando servicio DHCP...
    sc start dhcp
)
sc query "Dnscache" | find "RUNNING" >nul
if errorlevel 1 (
    echo   Iniciando servicio DNS Client...
    sc start "Dnscache"
)
echo   -^> Listo.
echo.

echo [FASE 2 - PASO 6/6] Vaciando cache DNS final y verificando adaptador...
ipconfig /flushdns
netsh interface show interface
echo   -^> Listo.
echo.

echo ================================================================
echo  Optimizacion completada en 2 fases.
echo ================================================================
pause
exit
