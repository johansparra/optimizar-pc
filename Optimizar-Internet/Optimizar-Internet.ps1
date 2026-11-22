<#PSScriptInfo
.VERSION 1.1.1
.GUID 5a4e60f0-e762-43fe-b7e2-b4af84d52483
.AUTHOR johansparra
.PROJECTURI https://github.com/johansparra/optimizar-pc
.RELEASENOTES
1.1.1 (2026-11-22): renovar la IP ya no se queda colgado cuando el router no da IP (pasa al prender el PC): espera máximo 30 segundos, avisa en rojo y sigue con el diagnóstico.
#>

<#
.SYNOPSIS
Renueva la IP (si no hay VPN), revisa la conexión paso a paso y, como admin, hace el mantenimiento de red.
.DESCRIPTION
Doble clic en Optimizar-Internet.bat: renovar IP y diagnóstico. Clic derecho > Ejecutar como administrador: también mantenimiento y tus ajustes de red.
.NOTES
Orden del archivo: CHEQUEO INICIAL > CONFIGURACIÓN > VISTA > MÉTODOS REUTILIZABLES > CONEXIÓN Y DIAGNÓSTICO > MANTENIMIENTO (solo admin) > MAIN (al final, como en Java).
Versión y nota de la versión actual: bloque PSScriptInfo de arriba. Historial de versiones: CHANGELOG.md en la raíz del repositorio. Los dos se mantienen con la skill actualizar-version-scripts.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Los colores en la consola son la interfaz: el script se abre con doble clic.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Se abre con doble clic: nadie usa -WhatIf ni -Confirm.')]
param()

# ════════ CHEQUEO INICIAL ════════

# Si la empresa restringe PowerShell (modo de lenguaje restringido), avisar y no hacer nada.
if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Write-Host '   PowerShell está restringido en este equipo por política de la empresa: esta herramienta no se ejecuta aquí.' -ForegroundColor Red
    return
}

# ════════ CONFIGURACIÓN ════════

$ServidorInternet = '8.8.8.8'             # servidor público para medir internet (solo sin VPN)
$PaginaPruebaDns  = 'www.microsoft.com'   # nombre que se busca para probar el DNS
$MsRouter         = 15                    # respuesta del router (ms): más que esto, amarillo
$MsRouterMalo     = 50                    #                         más que esto, rojo
$MsInternet       = 60                    # respuesta de internet (ms): más que esto, amarillo
$MsInternetMalo   = 150                   #                            más que esto, rojo
$SegundosRenovarIP = 30                   # máximo que se espera a que el router dé la IP
# Adaptadores virtuales que NO son VPN (máquinas virtuales y similares)
$NoEsVpn = 'Hyper-V|vEthernet|VMware|VirtualBox|Loopback|Bluetooth|WSL|Docker|Npcap|Wi-Fi Direct'

# Tus ajustes (solo corren como admin). Se escriben igual que en un .cmd.
$AdaptadorDns  = 'Ethernet'               # adaptador al que se le fija el DNS
$DnsPrimario   = '8.8.8.8'
$DnsSecundario = '8.8.4.4'
$AjustesTcp = @(
    'netsh int tcp set heuristics disabled'
    'netsh int tcp set global autotuninglevel=normal'
    'netsh int tcp set global rss=enabled'
    'netsh int tcp set global rsc=disabled'
    'netsh int tcp set supplemental Internet congestionprovider=ctcp'
    'netsh int tcp set global timestamps=disabled'
    'netsh int tcp set global ecncapability=disabled'
    'netsh int tcp set global initialrto=2000'
    'netsh int tcp set global maxsynretransmissions=2'
)

# ════════ VISTA (todo lo visual está aquí: colores y títulos) ════════

# Cada resultado tiene un tipo; aquí se decide su color.
$Colores = @{ ok = 'Green'; aviso = 'Yellow'; mal = 'Red'; info = 'DarkGray'; normal = 'Gray' }

# Título grande al abrir el script.
function Write-Header($texto) {
    $Host.UI.RawUI.WindowTitle = $texto
    $linea = '═' * 62
    Write-Host ''
    Write-Host "  $linea" -ForegroundColor DarkCyan
    Write-Host "   $texto" -ForegroundColor Cyan
    Write-Host "  $linea" -ForegroundColor DarkCyan
}

# Título de cada sección, con una raya debajo.
function Write-Title($texto) {
    Write-Host ''
    Write-Host "   $texto" -ForegroundColor Cyan
    Write-Host ('   ' + '─' * 58) -ForegroundColor DarkGray
}

# Una línea del reporte: qué se hizo a la izquierda, resultado a la derecha con el color de su tipo.
function Write-Line($nombre, $resultado, $tipo = 'normal') {
    Write-Host ('   {0,-32} ' -f $nombre) -NoNewline   # el espacio final separa aunque el nombre sea largo
    Write-Host $resultado -ForegroundColor $Colores[$tipo]
}

# ════════ MÉTODOS REUTILIZABLES ════════

# $true si el script se abrió con "Ejecutar como administrador" (funciona con Windows en cualquier idioma).
function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Cable y Wi-Fi conectados.
function Get-PhysicalAdapter {
    @(Get-NetAdapter -Physical | Where-Object Status -eq 'Up')
}

# VPN o Zscaler: cualquier otro adaptador conectado que no esté en $NoEsVpn.
function Get-Vpn($fisicos) {
    @(Get-NetAdapter | Where-Object {
        $_.Status -eq 'Up' -and $_.ifIndex -notin $fisicos.ifIndex -and
        "$($_.Name) $($_.InterfaceDescription)" -notmatch $NoEsVpn
    })
}

# 4 pings. Verde: responden todos a tiempo. Amarillo: se pierde alguno o tardan más de $msAviso.
# Rojo: se pierde la mitad o más, o tardan más de $msMal.
function Test-Ping($nombre, $destino, $msAviso, $msMal) {
    $respuestas = @(Test-Connection $destino -Count 4 -ErrorAction SilentlyContinue)
    if ($respuestas.Count -eq 0) { Write-Line $nombre "$destino no responde (algunos equipos bloquean el ping)" -tipo 'aviso'; return }
    $promedio = ($respuestas | Measure-Object ResponseTime -Average).Average
    $tipo = if ($respuestas.Count -le 2 -or $promedio -gt $msMal) { 'mal' }
            elseif ($respuestas.Count -lt 4 -or $promedio -gt $msAviso) { 'aviso' }
            else { 'ok' }
    Write-Line $nombre ('{0}: {1} de 4 respuestas, {2:N0} ms' -f $destino, $respuestas.Count, $promedio) -tipo $tipo
}

# Ejecuta uno o varios comandos escritos igual que en un .cmd, oculta su texto y reporta si salieron bien.
function Invoke-CmdLine($nombre, $comandos) {
    $fallidos = @()
    foreach ($comando in $comandos) {
        $null = cmd /c "$comando 2>&1"
        if ($LASTEXITCODE -ne 0) { $fallidos += $comando }
    }
    if (-not $fallidos) { Write-Line $nombre 'OK' -tipo 'ok' }
    else                { Write-Line $nombre ('falló: ' + ($fallidos -join ' | ')) -tipo 'mal' }
}

# ════════ CONEXIÓN Y DIAGNÓSTICO (sin admin; un método = una tarea) ════════

# Si el router no da IP (pasa al prender el PC), ipconfig se queda esperando minutos: por eso hay límite.
# Al agotarse, ipconfig sigue intentando por su cuenta y el script continúa. Su texto va a nul, sin ventana oculta.
function Update-IP($adaptador) {
    $nombre = "Renovar IP: $($adaptador.Name)"
    $inicio = New-Object Diagnostics.ProcessStartInfo -Property @{
        FileName = 'cmd'; UseShellExecute = $false
        Arguments = "/c ipconfig /renew `"$($adaptador.Name)`" >nul 2>&1"   # nunca /release: ese corta la conexión
    }
    $ipconfig = [Diagnostics.Process]::Start($inicio)
    if (-not $ipconfig.WaitForExit($SegundosRenovarIP * 1000)) {
        Write-Line $nombre "el router no dio IP en $SegundosRenovarIP s: revisa el cable o reinicia el router" -tipo 'mal'
    }
    elseif ($ipconfig.ExitCode -eq 0) { Write-Line $nombre 'OK' -tipo 'ok' }
    else                              { Write-Line $nombre 'no se renovó (puede tener IP fija)' -tipo 'aviso' }
}

function Show-Connection($adaptador) {
    $c = Get-NetIPConfiguration -InterfaceIndex $adaptador.ifIndex
    # Cable (NdisPhysicalMedium 14 = Ethernet) conectado a menos de 1 Gbps: suele ser el cable o el puerto.
    if ($adaptador.NdisPhysicalMedium -eq 14 -and $adaptador.ReceiveLinkSpeed -lt 1e9) {
        Write-Line $adaptador.Name "$($adaptador.LinkSpeed) (si tu plan es más rápido, cambia el cable a Cat 5e o más, o el puerto)" -tipo 'aviso'
    } else {
        Write-Line $adaptador.Name $adaptador.LinkSpeed
    }
    Write-Line '  IP' ($c.IPv4Address.IPAddress -join ', ')
    Write-Line '  Router' ($c.IPv4DefaultGateway.NextHop -join ', ')
    Write-Line '  DNS' ((($c.DNSServer | Where-Object AddressFamily -eq 2).ServerAddresses) -join ', ')
}

# Red, señal, banda y velocidad (Windows en español o en inglés). La señal sale en color.
function Show-Wifi {
    # netsh entrega su texto en UTF-8; sin esto "Señal" llega como "Se├▒al" y no se reconoce.
    $codificacion = [Console]::OutputEncoding
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    try     { $lineas = netsh wlan show interfaces | Select-String '^\s*(SSID|Se.al|Signal|Banda|Band|Velocidad|.*rate)\b' }
    finally { [Console]::OutputEncoding = $codificacion }
    if (-not $lineas) { return }   # sin Wi-Fi
    Write-Line 'Datos del Wi-Fi' ''
    foreach ($linea in $lineas) {
        $nombre, $valor = ($linea.Line -split ':', 2).Trim()
        $tipo = 'normal'
        if ($nombre -match 'Se.al|Signal') {
            $senal = [int]($valor -replace '\D')
            $tipo = if ($senal -lt 40) { 'mal' } elseif ($senal -lt 70) { 'aviso' } else { 'ok' }
        }
        Write-Line "  $nombre" $valor -tipo $tipo
    }
}

# DHCP y Cliente DNS tienen que estar corriendo. Si no lo están y eres admin, se inician.
# Main los revisa antes de renovar la IP (necesita DHCP) y de vaciar la caché DNS (necesita Cliente DNS).
function Test-NetService($nombre, $servicio) {
    if ((Get-Service $servicio).Status -ne 'Running' -and (Test-Admin)) {
        Start-Service $servicio -ErrorAction SilentlyContinue
    }
    $estado = (Get-Service $servicio).Status
    if ($estado -eq 'Running') { Write-Line $nombre 'en ejecución' -tipo 'ok' }
    else                       { Write-Line $nombre "$estado (como admin se intenta iniciar)" -tipo 'mal' }
}

# Un ping por router, aunque el cable y el Wi-Fi usen el mismo.
function Test-Router($adaptadores) {
    $routers = $adaptadores | ForEach-Object { (Get-NetIPConfiguration -InterfaceIndex $_.ifIndex).IPv4DefaultGateway.NextHop } | Sort-Object -Unique
    foreach ($router in $routers) { Test-Ping 'Ping al router' $router -msAviso $MsRouter -msMal $MsRouterMalo }
}

function Test-Internet {
    Test-Ping 'Ping a internet' $ServidorInternet -msAviso $MsInternet -msMal $MsInternetMalo
}

# Basta con que una conexión tenga internet (con VPN, la salida va por la VPN y las demás quedan como red local).
function Show-InternetAccess {
    $conInternet = @(Get-NetConnectionProfile | Where-Object { $_.IPv4Connectivity -eq 'Internet' -or $_.IPv6Connectivity -eq 'Internet' })
    if ($conInternet) { Write-Line 'Windows ve internet' ('sí, por ' + ($conInternet.InterfaceAlias -join ', ')) -tipo 'ok' }
    else              { Write-Line 'Windows ve internet' 'no: hay red, pero no salida a internet' -tipo 'mal' }
}

function Test-DnsResolution {
    $reloj = [Diagnostics.Stopwatch]::StartNew()
    $respuesta = Resolve-DnsName $PaginaPruebaDns -Type A -DnsOnly -QuickTimeout -ErrorAction SilentlyContinue
    if ($respuesta) { Write-Line 'DNS' ('responde ({0:N0} ms)' -f $reloj.Elapsed.TotalMilliseconds) -tipo 'ok' }
    else            { Write-Line 'DNS' 'no responde' -tipo 'mal' }
}

# ════════ MANTENIMIENTO (solo administrador: Main los salta si no lo eres) ════════

function Clear-DnsCache {
    Invoke-CmdLine 'Vaciar caché DNS' 'ipconfig /flushdns'
}

function Clear-NetbiosCache {
    Invoke-CmdLine 'Vaciar caché NetBIOS' 'nbtstat -R', 'nbtstat -RR'
}

function Clear-ArpCache {
    Invoke-CmdLine 'Vaciar caché ARP' 'arp -d *'
}

# La lista está en CONFIGURACIÓN ($AjustesTcp).
function Set-TcpSetting {
    Invoke-CmdLine 'Ajustes TCP' $AjustesTcp
}

# Teredo: túnel IPv6 antiguo. Ojo: el chat de grupo de la app Xbox lo necesita.
function Disable-Teredo {
    Invoke-CmdLine 'Desactivar Teredo' 'netsh interface teredo set state disabled'
}

# DNS fijo en el adaptador de CONFIGURACIÓN ($AdaptadorDns, $DnsPrimario, $DnsSecundario).
function Set-StaticDnsServer {
    Invoke-CmdLine "DNS fijo en $AdaptadorDns" @(
        ('netsh interface ip set dns name="{0}" static {1}' -f $AdaptadorDns, $DnsPrimario)
        ('netsh interface ip add dns name="{0}" {1} index=2' -f $AdaptadorDns, $DnsSecundario)
    )
}

# --- Reparación profunda: solo admin, solo si dices que sí, y hay que reiniciar después --------

function Confirm-DeepRepair {
    (Read-Host '   ¿Hacer también la reparación profunda? Restablece firewall, IP y Winsock y luego hay que reiniciar (S/N)') -match '^\s*s'
}

# Ojo: borra las reglas que tus programas agregaron al firewall de Windows (las vuelven a pedir).
function Reset-Firewall {
    Invoke-CmdLine 'Restablecer firewall' 'netsh advfirewall reset'
}

function Reset-IP {
    Invoke-CmdLine 'Restablecer IP' 'netsh int ipv4 reset', 'netsh int ip reset'
}

function Reset-Winsock {
    Invoke-CmdLine 'Restablecer Winsock' 'netsh winsock reset'
}

function Reset-Proxy {
    Invoke-CmdLine 'Restablecer proxy (WinHTTP)' 'netsh winhttp reset proxy'
}
# ------------------------------------------------------------------------------------------------

# ════════ MAIN ════════

function Main {
    Write-Header 'OPTIMIZAR INTERNET'

    # 1. Primero: permisos, conexión y VPN. Eso decide qué se puede hacer.
    $esAdmin = Test-Admin
    if ($esAdmin) { Write-Line 'Modo' 'administrador: diagnóstico + mantenimiento de red' -tipo 'ok' }
    else          { Write-Line 'Modo' 'normal: renovar IP y diagnóstico (el mantenimiento pide admin)' -tipo 'info' }
    $fisicos = Get-PhysicalAdapter
    if (-not $fisicos) { Write-Line 'Conexión' 'no hay cable ni Wi-Fi conectado' -tipo 'mal'; return }
    $vpn = Get-Vpn $fisicos
    if ($vpn) { Write-Line 'VPN conectada' $vpn[0].InterfaceDescription -tipo 'info' }

    # 2. La única pregunta va al principio; el resto corre sin interrupciones. Con VPN no se ofrece.
    $reparar = $false
    if ($esAdmin -and -not $vpn) { $reparar = Confirm-DeepRepair }

    # 3. Servicios primero (como admin se inician si están apagados): renovar la IP y vaciar la caché DNS
    #    los necesitan. Luego renovar la IP antes de tocar nada más. Con VPN se salta para no cortarla.
    Write-Title 'Renovar conexión'
    Test-NetService 'Servicio DHCP' 'Dhcp'
    Test-NetService 'Servicio Cliente DNS' 'Dnscache'
    if ($vpn) { Write-Line 'Renovar IP' 'se salta para no cortar la VPN' -tipo 'info' }
    else      { foreach ($a in $fisicos) { Update-IP $a } }

    # 4. Mantenimiento (solo admin): primero restablecer, luego tus ajustes (si fuera al revés, restablecer
    #    los borraría) y al final vaciar cachés, para que no quede nada guardado de antes de los cambios.
    if ($esAdmin) {
        Write-Title 'Mantenimiento de red'
        if ($reparar) {
            Reset-Firewall
            Reset-IP
            Reset-Winsock
            Reset-Proxy
        }
        Set-TcpSetting
        Disable-Teredo
        Set-StaticDnsServer
        Clear-DnsCache
        Clear-NetbiosCache
        Clear-ArpCache
    }

    # 5. Datos y diagnóstico con todo ya aplicado, de lo más cercano (router) a lo más lejano (internet, DNS).
    Write-Title 'Tu conexión'
    foreach ($a in $fisicos) { Show-Connection $a }
    Show-Wifi

    Write-Title 'Diagnóstico'
    Test-Router $fisicos
    if ($vpn) { Write-Line 'Ping a internet' 'se salta con VPN' -tipo 'info' }
    else      { Test-Internet }
    Show-InternetAccess
    Test-DnsResolution

    if ($reparar) { Write-Line 'Reparación profunda' 'reinicia el PC para terminarla' -tipo 'aviso' }
    Write-Title 'Listo'
}

Main
