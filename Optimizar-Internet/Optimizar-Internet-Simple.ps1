# Optimizar-Internet-Simple.ps1 - Renueva la IP (si no hay VPN), revisa la conexión paso a paso y, como admin, hace el mantenimiento de red.
# Doble clic: renovar IP y diagnóstico. Clic derecho > Ejecutar como administrador: también mantenimiento y tus ajustes.
# Orden del archivo: CONFIGURACIÓN > VISTA > MÉTODOS REUTILIZABLES > CONEXIÓN Y DIAGNÓSTICO > MANTENIMIENTO (solo admin) > MAIN (al final, como en Java).

# ════════ CONFIGURACIÓN ════════

$ServidorInternet = '8.8.8.8'             # servidor público para medir internet (solo sin VPN)
$PaginaPruebaDns  = 'www.microsoft.com'   # nombre que se busca para probar el DNS
$MsRouter         = 15                    # respuesta normal del router (ms); más que esto, aviso
$MsInternet       = 60                    # respuesta normal de internet (ms); más que esto, aviso
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
function Escribir-Encabezado($texto) {
    $Host.UI.RawUI.WindowTitle = $texto
    $linea = '═' * 62
    Write-Host ''
    Write-Host "  $linea" -ForegroundColor DarkCyan
    Write-Host "   $texto" -ForegroundColor Cyan
    Write-Host "  $linea" -ForegroundColor DarkCyan
}

# Título de cada sección, con una raya debajo.
function Escribir-Titulo($texto) {
    Write-Host ''
    Write-Host "   $texto" -ForegroundColor Cyan
    Write-Host ('   ' + '─' * 58) -ForegroundColor DarkGray
}

# Una línea del reporte: qué se hizo a la izquierda, resultado a la derecha con el color de su tipo.
function Escribir-Linea($nombre, $resultado, $tipo = 'normal') {
    Write-Host ('   {0,-32} ' -f $nombre) -NoNewline   # el espacio final separa aunque el nombre sea largo
    Write-Host $resultado -ForegroundColor $Colores[$tipo]
}

# ════════ MÉTODOS REUTILIZABLES ════════

# $true si el script se abrió con "Ejecutar como administrador" (funciona con Windows en cualquier idioma).
function Es-Administrador {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Cable y Wi-Fi conectados.
function Obtener-AdaptadoresFisicos {
    @(Get-NetAdapter -Physical | Where-Object Status -eq 'Up')
}

# VPN o Zscaler: cualquier otro adaptador conectado que no esté en $NoEsVpn.
function Obtener-Vpn($fisicos) {
    @(Get-NetAdapter | Where-Object {
        $_.Status -eq 'Up' -and $_.ifIndex -notin $fisicos.ifIndex -and
        "$($_.Name) $($_.InterfaceDescription)" -notmatch $NoEsVpn
    })
}

# 4 pings: verde si responden todos a tiempo, amarillo si se pierden o tardan más de $msMaximo.
function Hacer-Ping($nombre, $destino, $msMaximo) {
    $respuestas = @(Test-Connection $destino -Count 4 -ErrorAction SilentlyContinue)
    if ($respuestas.Count -eq 0) { Escribir-Linea $nombre "$destino no responde (algunos equipos bloquean el ping)" 'aviso'; return }
    $promedio = ($respuestas | Measure-Object ResponseTime -Average).Average
    $tipo = if ($respuestas.Count -lt 4 -or $promedio -gt $msMaximo) { 'aviso' } else { 'ok' }
    Escribir-Linea $nombre ('{0}: {1} de 4 respuestas, {2:N0} ms' -f $destino, $respuestas.Count, $promedio) $tipo
}

# Ejecuta uno o varios comandos escritos igual que en un .cmd, oculta su texto y reporta si salieron bien.
function Ejecutar-Comandos($nombre, $comandos) {
    $fallidos = @()
    foreach ($comando in $comandos) {
        $null = cmd /c "$comando 2>&1"
        if ($LASTEXITCODE -ne 0) { $fallidos += $comando }
    }
    if (-not $fallidos) { Escribir-Linea $nombre 'OK' 'ok' }
    else                { Escribir-Linea $nombre ('falló: ' + ($fallidos -join ' | ')) 'mal' }
}

# ════════ CONEXIÓN Y DIAGNÓSTICO (sin admin; un método = una tarea) ════════

function Renovar-IP($adaptador) {
    $null = ipconfig /renew "$($adaptador.Name)" 2>&1   # nunca /release: ese corta la conexión
    if ($LASTEXITCODE -eq 0) { Escribir-Linea "Renovar IP: $($adaptador.Name)" 'OK' 'ok' }
    else                     { Escribir-Linea "Renovar IP: $($adaptador.Name)" 'no se renovó (puede tener IP fija)' 'aviso' }
}

function Mostrar-Conexion($adaptador) {
    $c = Get-NetIPConfiguration -InterfaceIndex $adaptador.ifIndex
    Escribir-Linea $adaptador.Name $adaptador.LinkSpeed
    Escribir-Linea '  IP' ($c.IPv4Address.IPAddress -join ', ')
    Escribir-Linea '  Router' ($c.IPv4DefaultGateway.NextHop -join ', ')
    Escribir-Linea '  DNS' ((($c.DNSServer | Where-Object AddressFamily -eq 2).ServerAddresses) -join ', ')
}

# Red, señal, banda y velocidad (Windows en español o en inglés). La señal sale en color.
function Mostrar-Wifi {
    $lineas = netsh wlan show interfaces | Select-String '^\s*(SSID|Se.al|Signal|Banda|Band|Velocidad|.*rate)\b'
    if (-not $lineas) { return }   # sin Wi-Fi
    Escribir-Linea 'Wi-Fi' ''
    foreach ($linea in $lineas) {
        $nombre, $valor = ($linea.Line -split ':', 2).Trim()
        $tipo = 'normal'
        if ($nombre -match 'Se.al|Signal') {
            $senal = [int]($valor -replace '\D')
            $tipo = if ($senal -lt 40) { 'mal' } elseif ($senal -lt 70) { 'aviso' } else { 'ok' }
        }
        Escribir-Linea "  $nombre" $valor $tipo
    }
}

# DHCP y Cliente DNS tienen que estar corriendo. Si no lo están y eres admin, se inician.
function Probar-Servicio($nombre, $servicio) {
    if ((Get-Service $servicio).Status -ne 'Running' -and (Es-Administrador)) {
        Start-Service $servicio -ErrorAction SilentlyContinue
    }
    $estado = (Get-Service $servicio).Status
    if ($estado -eq 'Running') { Escribir-Linea $nombre 'en ejecución' 'ok' }
    else                       { Escribir-Linea $nombre "$estado (como admin se intenta iniciar)" 'mal' }
}

function Probar-Router($adaptador) {
    foreach ($router in (Get-NetIPConfiguration -InterfaceIndex $adaptador.ifIndex).IPv4DefaultGateway.NextHop) {
        Hacer-Ping 'Ping al router' $router $MsRouter
    }
}

function Probar-Internet {
    Hacer-Ping 'Ping a internet' $ServidorInternet $MsInternet
}

function Mostrar-SalidaInternet {
    foreach ($perfil in Get-NetConnectionProfile) {
        $tipo = if ($perfil.IPv4Connectivity -eq 'Internet') { 'ok' } else { 'mal' }
        Escribir-Linea 'Windows ve internet' ('{0}: {1}' -f $perfil.InterfaceAlias, $perfil.IPv4Connectivity) $tipo
    }
}

function Probar-Dns {
    $tiempo = Measure-Command { $respuesta = Resolve-DnsName $PaginaPruebaDns -Type A -DnsOnly -QuickTimeout -ErrorAction SilentlyContinue }
    if ($respuesta) { Escribir-Linea 'DNS' ('responde ({0:N0} ms)' -f $tiempo.TotalMilliseconds) 'ok' }
    else            { Escribir-Linea 'DNS' 'no responde' 'mal' }
}

# ════════ MANTENIMIENTO (solo administrador: Main los salta si no lo eres) ════════

function Vaciar-CacheDns {
    Ejecutar-Comandos 'Vaciar caché DNS' 'ipconfig /flushdns'
}

function Vaciar-CacheNetbios {
    Ejecutar-Comandos 'Vaciar caché NetBIOS' 'nbtstat -R', 'nbtstat -RR'
}

function Vaciar-CacheArp {
    Ejecutar-Comandos 'Vaciar caché ARP' 'arp -d *'
}

# La lista está en CONFIGURACIÓN ($AjustesTcp).
function Aplicar-AjustesTcp {
    Ejecutar-Comandos 'Ajustes TCP' $AjustesTcp
}

# Teredo: túnel IPv6 antiguo. Ojo: el chat de grupo de la app Xbox lo necesita.
function Desactivar-Teredo {
    Ejecutar-Comandos 'Desactivar Teredo' 'netsh interface teredo set state disabled'
}

# DNS fijo en el adaptador de CONFIGURACIÓN ($AdaptadorDns, $DnsPrimario, $DnsSecundario).
function Fijar-Dns {
    Ejecutar-Comandos "DNS fijo en $AdaptadorDns" @(
        ('netsh interface ip set dns name="{0}" static {1}' -f $AdaptadorDns, $DnsPrimario)
        ('netsh interface ip add dns name="{0}" {1} index=2' -f $AdaptadorDns, $DnsSecundario)
    )
}

# --- Reparación profunda: solo admin, solo si dices que sí, y hay que reiniciar después --------

function Preguntar-ReparacionProfunda {
    (Read-Host '   ¿Hacer también la reparación profunda? Restablece firewall, IP y Winsock y luego hay que reiniciar (S/N)') -match '^\s*s'
}

# Ojo: borra las reglas que tus programas agregaron al firewall de Windows (las vuelven a pedir).
function Restablecer-Firewall {
    Ejecutar-Comandos 'Restablecer firewall' 'netsh advfirewall reset'
}

function Restablecer-IP {
    Ejecutar-Comandos 'Restablecer IP' 'netsh int ipv4 reset', 'netsh int ip reset'
}

function Restablecer-Winsock {
    Ejecutar-Comandos 'Restablecer Winsock' 'netsh winsock reset'
}

function Restablecer-Proxy {
    Ejecutar-Comandos 'Restablecer proxy (WinHTTP)' 'netsh winhttp reset proxy'
}
# ------------------------------------------------------------------------------------------------

# ════════ MAIN ════════

function Main {
    Escribir-Encabezado 'OPTIMIZAR INTERNET'

    # 1. Primero: permisos, conexión y VPN. Eso decide qué se puede hacer.
    $esAdmin = Es-Administrador
    if ($esAdmin) { Escribir-Linea 'Modo' 'administrador: diagnóstico + mantenimiento de red' 'ok' }
    else          { Escribir-Linea 'Modo' 'normal: renovar IP y diagnóstico (el mantenimiento pide admin)' 'info' }
    $fisicos = Obtener-AdaptadoresFisicos
    if (-not $fisicos) { Escribir-Linea 'Conexión' 'no hay cable ni Wi-Fi conectado' 'mal'; return }
    $vpn = Obtener-Vpn $fisicos
    if ($vpn) { Escribir-Linea 'VPN conectada' $vpn[0].InterfaceDescription 'info' }

    # 2. La única pregunta va al principio; el resto corre sin interrupciones. Con VPN no se ofrece.
    $reparar = $false
    if ($esAdmin -and -not $vpn) { $reparar = Preguntar-ReparacionProfunda }

    # 3. Renovar la IP antes de tocar nada más, mientras la red está sana. Con VPN se salta para no cortarla.
    Escribir-Titulo 'Renovar conexión'
    if ($vpn) { Escribir-Linea 'Renovar IP' 'se salta para no cortar la VPN' 'info' }
    else      { foreach ($a in $fisicos) { Renovar-IP $a } }

    # 4. Mantenimiento (solo admin), en el orden de tu .cmd: primero restablecer, luego vaciar cachés
    #    y al final tus ajustes, para que queden puestos sobre la red ya restablecida.
    if ($esAdmin) {
        Escribir-Titulo 'Mantenimiento de red'
        if ($reparar) {
            Restablecer-Firewall
            Restablecer-IP
            Restablecer-Winsock
            Restablecer-Proxy
        }
        Vaciar-CacheDns
        Vaciar-CacheNetbios
        Vaciar-CacheArp
        Aplicar-AjustesTcp
        Desactivar-Teredo
        Fijar-Dns
    }

    # 5. Datos y diagnóstico con todo ya aplicado, de lo más cercano (servicios, router) a lo más lejano (internet, DNS).
    Escribir-Titulo 'Tu conexión'
    foreach ($a in $fisicos) { Mostrar-Conexion $a }
    Mostrar-Wifi

    Escribir-Titulo 'Diagnóstico'
    Probar-Servicio 'Servicio DHCP' 'Dhcp'
    Probar-Servicio 'Servicio Cliente DNS' 'Dnscache'
    foreach ($a in $fisicos) { Probar-Router $a }
    if ($vpn) { Escribir-Linea 'Ping a internet' 'se salta con VPN' 'info' }
    else      { Probar-Internet }
    Mostrar-SalidaInternet
    Probar-Dns

    if ($reparar) { Escribir-Linea 'Reparación profunda' 'reinicia el PC para terminarla' 'aviso' }
    Escribir-Titulo 'Listo'
}

Main
