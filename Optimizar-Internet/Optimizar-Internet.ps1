<#
    Optimizar-Internet.ps1  -  Renueva la conexión y revisa dónde está el problema.
    NO necesita permisos de administrador.

    Qué hace
      1. Renueva la IP de tu cable / Wi-Fi (como "ipconfig /renew"), sin cortar
         la conexión. Si hay una VPN conectada (Cisco, Zscaler...), no renueva
         nada para no afectarla. Nunca usa "ipconfig /release", porque ese corta.
      2. Intenta vaciar la caché DNS. En Windows 11 eso pide administrador; si
         es así, se omite y lo dice.
      3. Revisa la conexión: señal Wi-Fi, velocidad del enlace, respuesta del
         router, de internet y del DNS, y te dice qué mejorar.

    Sin administrador Windows no deja cambiar ajustes de red, y la mayoría de
    "trucos" para acelerar internet no hacen nada en Windows 10/11. Lo útil es
    renovar la conexión y saber si el problema es el Wi-Fi, el router o internet.

    Uso
      Doble clic en Optimizar-Internet.bat
#>

$DestinoInternet = '8.8.8.8'   # servidor público al que se mide la respuesta de internet

function Write-Titulo([string]$Texto) {
    $linea = '═' * 62
    Write-Host ''
    Write-Host "  $linea" -ForegroundColor DarkCyan
    Write-Host "   $Texto" -ForegroundColor Cyan
    Write-Host "  $linea" -ForegroundColor DarkCyan
}

function Write-Seccion([string]$Texto) {
    Write-Host ''
    Write-Host "   $Texto" -ForegroundColor Cyan
    Write-Host ('   ' + '─' * 58) -ForegroundColor DarkGray
}

function Write-Estado([string]$Tipo, [string]$Texto) {
    switch ($Tipo) {
        'ok'    { $marca = 'OK'; $color = 'Green' }
        'aviso' { $marca = '!!'; $color = 'Yellow' }
        'mal'   { $marca = 'XX'; $color = 'Red' }
        default { $marca = '--'; $color = 'DarkGray' }
    }
    Write-Host '   [' -NoNewline
    Write-Host $marca -ForegroundColor $color -NoNewline
    Write-Host "] $Texto"
}

function Write-Dato([string]$Etiqueta, [string]$Texto) {
    Write-Host ('   {0,-10} ' -f $Etiqueta) -ForegroundColor Gray -NoNewline
    Write-Host $Texto
}

function Write-Vineta([string]$Texto) {
    # Escribe un punto de la lista partiendo las líneas largas
    $linea = '   • '
    foreach ($palabra in $Texto -split ' ') {
        if ($linea.Length + $palabra.Length -gt 76) { Write-Host $linea.TrimEnd(); $linea = '     ' }
        $linea += "$palabra "
    }
    Write-Host $linea.TrimEnd()
}

function Format-Velocidad([double]$Bps) {
    if ($Bps -ge 1e9) { return '{0:0.#} Gbps' -f ($Bps / 1e9) }
    return '{0:N0} Mbps' -f ($Bps / 1e6)
}

function Format-Perdida([int]$Pct) {
    if ($Pct -eq 0) { return 'sin pérdidas' }
    return "$Pct % perdido"
}

function Test-Ping([string]$Destino, [int]$Veces = 4) {
    $tiempos = @()
    for ($i = 0; $i -lt $Veces; $i++) {
        $r = Get-CimInstance Win32_PingStatus -Filter "Address='$Destino' AND Timeout=1000" -ErrorAction SilentlyContinue
        if ($r -and $r.StatusCode -eq 0) { $tiempos += [int]$r.ResponseTime }
    }
    $promedio = $null
    if ($tiempos.Count) { $promedio = [int][math]::Round(($tiempos | Measure-Object -Average).Average) }
    [pscustomobject]@{ Promedio = $promedio; Perdida = [int](100 * ($Veces - $tiempos.Count) / $Veces) }
}

function Get-InfoWifi {
    # netsh viene con Windows. En algunos equipos pide tener la ubicación activada;
    # si no la tiene, simplemente no se muestra la señal.
    $info = @{}
    foreach ($linea in (netsh wlan show interfaces 2>$null)) {
        if ($linea -match '^\s*SSID\s*:\s*(.+?)\s*$')           { $info.Red = $Matches[1] }
        elseif ($linea -match ':\s*(\d{1,3})\s*%\s*$')          { $info.Senal = [int]$Matches[1] }
        elseif ($linea -match ':\s*(\d+(?:[.,]\d+)?)\s*GHz\s*$') { $info.Banda = "$($Matches[1]) GHz" }
    }
    $info
}

# ─── Programa ────────────────────────────────────────────────────────────────

if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Write-Host ''
    Write-Host '  PowerShell está restringido en este equipo por política de la empresa.' -ForegroundColor Red
    Write-Host '  Esta herramienta no se ejecuta aquí.' -ForegroundColor Red
    return
}

$Host.UI.RawUI.WindowTitle = 'Optimizar internet'
Write-Titulo 'OPTIMIZAR INTERNET'

$fisicos = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up' | Sort-Object ifIndex)
if (-not $fisicos) {
    Write-Host ''
    Write-Estado mal 'No hay ningún cable ni Wi-Fi conectado.'
    Write-Host '        Conecta el cable o elige una red Wi-Fi y vuelve a ejecutar.' -ForegroundColor DarkGray
    return
}
$recomendaciones = New-Object System.Collections.Generic.List[string]

# VPN / Zscaler: adaptadores virtuales conectados que no son de máquinas virtuales
$ignorar = 'VMware|VirtualBox|Hyper-V|vEthernet|Loopback|Bluetooth|WSL|Docker|Npcap|Wi-Fi Direct'
$vpn = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
    $_.Status -eq 'Up' -and $fisicos.ifIndex -notcontains $_.ifIndex -and
    $_.InterfaceDescription -notmatch $ignorar -and $_.Name -notmatch $ignorar
})

# 1. Renovar ------------------------------------------------------------------
Write-Seccion '1. Renovando la conexión'
$porRenovar = $fisicos
if ($vpn) {
    Write-Estado info 'Hay una VPN conectada: no se renueva la IP para no cortarla'
    $porRenovar = @()
}
foreach ($adaptador in $porRenovar) {
    $ipv4 = Get-NetIPInterface -InterfaceIndex $adaptador.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($ipv4.Dhcp -ne 'Enabled') {
        Write-Estado info "$($adaptador.Name): usa IP fija, no se renueva"
        continue
    }
    $salida = ipconfig /renew "$($adaptador.Name)" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Estado ok "IP renovada: $($adaptador.Name)"
    } else {
        $motivo = $salida | ForEach-Object { "$_".Trim() } | Where-Object { $_ } | Select-Object -Last 1
        Write-Estado aviso "No se pudo renovar $($adaptador.Name): $motivo"
    }
}
$null = ipconfig /flushdns 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Estado ok 'Caché DNS vaciada'
} else {
    Write-Estado info 'Caché DNS: este Windows pide administrador para vaciarla (se omite, no es grave)'
}
Start-Sleep -Seconds 2

# 2. Conexión -----------------------------------------------------------------
Write-Seccion '2. Tu conexión'
$wifi = $null
$routers = @()
foreach ($adaptador in $fisicos) {
    $conf = Get-NetIPConfiguration -InterfaceIndex $adaptador.ifIndex -ErrorAction SilentlyContinue
    $ip = @($conf.IPv4Address.IPAddress) -join ', '
    $router = @($conf.IPv4DefaultGateway.NextHop) | Where-Object { $_ } | Select-Object -First 1
    $dns = @(($conf.DNSServer | Where-Object AddressFamily -eq 2).ServerAddresses) -join ', '
    $velocidad = Format-Velocidad $adaptador.ReceiveLinkSpeed

    $tipo = switch ($adaptador.NdisPhysicalMedium) { 9 { 'Wi-Fi' } 8 { 'Móvil' } default { 'Cable' } }
    if ($tipo -eq 'Wi-Fi') {
        $wifi = Get-InfoWifi
        $partes = @()
        if ($wifi.Red)   { $partes += $wifi.Red }
        if ($wifi.Banda) { $partes += $wifi.Banda }
        if ($wifi.Senal) { $partes += "señal $($wifi.Senal) %" }
        $partes += $velocidad
        Write-Dato $tipo ($partes -join ' · ')
    } else {
        Write-Dato $tipo $velocidad
        if ($tipo -eq 'Cable' -and $adaptador.ReceiveLinkSpeed -gt 0 -and $adaptador.ReceiveLinkSpeed -lt 1e9) {
            $recomendaciones.Add("El cable conecta a solo $velocidad. Si tu plan es más rápido, cambia el cable (Cat 5e o superior) o el puerto del router.")
        }
    }
    $detalle = "IP $ip"
    if ($router) { $detalle += " · router $router" }
    if ($dns)    { $detalle += " · DNS $dns" }
    Write-Dato '' $detalle

    if ($ip -like '169.254.*') {
        $recomendaciones.Add("$($adaptador.Name) no recibió IP del router (169.254...). Desconecta y vuelve a conectar, o reinicia el router.")
    }
    if ($router) { $routers += $router }
}

foreach ($v in $vpn) {
    $nombre = $v.InterfaceDescription
    if ($nombre.Length -gt 55) { $nombre = $nombre.Substring(0, 54) + '…' }
    Write-Dato 'VPN' "$nombre (conectada)"
}

# 3. Diagnóstico --------------------------------------------------------------
Write-Seccion '3. Diagnóstico'

$perfiles = @(Get-NetConnectionProfile -ErrorAction SilentlyContinue)
if ($perfiles | Where-Object { $_.IPv4Connectivity -eq 'Internet' -or $_.IPv6Connectivity -eq 'Internet' }) {
    Write-Estado ok 'Windows detecta salida a internet'
} else {
    Write-Estado mal 'Hay red, pero Windows no detecta salida a internet'
    $recomendaciones.Add('Reinicia el router (desconéctalo 30 segundos). Si sigue igual, llama a tu proveedor de internet.')
}

if ($wifi -and $wifi.Senal) {
    if ($wifi.Senal -lt 40) {
        Write-Estado mal "Señal Wi-Fi débil ($($wifi.Senal) %)"
        $recomendaciones.Add('La señal Wi-Fi es débil: acércate al router, evita paredes entre ambos o usa cable.')
    } elseif ($wifi.Senal -lt 70) {
        Write-Estado aviso "Señal Wi-Fi regular ($($wifi.Senal) %)"
        $recomendaciones.Add('La señal Wi-Fi es regular: si puedes, acércate al router o usa cable.')
    } else {
        Write-Estado ok "Señal Wi-Fi buena ($($wifi.Senal) %)"
    }
    if ($wifi.Banda -like '2*') {
        $recomendaciones.Add('Estás en Wi-Fi de 2,4 GHz. Si tu router tiene una red de 5 GHz, úsala cuando estés cerca: suele ser más rápida.')
    }
}

foreach ($router in ($routers | Select-Object -Unique)) {
    $r = Test-Ping $router
    if ($null -eq $r.Promedio) {
        Write-Estado info "Router ($router): no responde al ping (algunos routers lo bloquean)"
        continue
    }
    $texto = "Router ($router): $($r.Promedio) ms, $(Format-Perdida $r.Perdida)"
    if ($r.Perdida -ge 50 -or $r.Promedio -gt 50) {
        Write-Estado mal $texto
        $recomendaciones.Add('La conexión entre tu PC y el router es mala: acércate, usa cable o reinicia el router.')
    } elseif ($r.Perdida -gt 0 -or $r.Promedio -gt 15) {
        Write-Estado aviso $texto
        $recomendaciones.Add('La conexión con el router tiene demoras o pérdidas: suele ser el Wi-Fi. Acércate o usa cable.')
    } else {
        Write-Estado ok $texto
    }
}

if ($vpn) {
    # Con VPN el tráfico sale por la red de la empresa: no se hace ping a servidores externos
    Write-Estado info 'Internet: con VPN no se mide por ping (la salida la revisó Windows arriba)'
} else {
    $r = Test-Ping $DestinoInternet
    if ($null -eq $r.Promedio) {
        Write-Estado info "Internet ($DestinoInternet): no responde al ping (algunas redes lo bloquean)"
    } else {
        $texto = "Internet ($DestinoInternet): $($r.Promedio) ms, $(Format-Perdida $r.Perdida)"
        if ($r.Perdida -ge 50 -or $r.Promedio -gt 150) {
            Write-Estado mal $texto
            $recomendaciones.Add('Internet responde lento o pierde datos. Si el router responde bien, el problema suele ser el proveedor.')
        } elseif ($r.Perdida -gt 0 -or $r.Promedio -gt 60) {
            Write-Estado aviso $texto
            $recomendaciones.Add('Internet tiene algo de demora. Si el router responde bien, puede ser el proveedor o la hora de más uso.')
        } else {
            Write-Estado ok $texto
        }
    }
}

$reloj = [Diagnostics.Stopwatch]::StartNew()
$resuelto = Resolve-DnsName -Name 'www.microsoft.com' -Type A -DnsOnly -QuickTimeout -ErrorAction SilentlyContinue
$reloj.Stop()
if (-not $resuelto) {
    Write-Estado mal 'DNS: no logra encontrar las páginas por su nombre'
    $recomendaciones.Add('El DNS no responde: reinicia el router. Si estás en la red de la empresa, avísale a soporte.')
} elseif ($reloj.ElapsedMilliseconds -gt 300) {
    Write-Estado aviso "DNS: responde lento ($($reloj.ElapsedMilliseconds) ms)"
} else {
    Write-Estado ok "DNS: responde ($($reloj.ElapsedMilliseconds) ms)"
}

# Recomendaciones -------------------------------------------------------------
Write-Seccion 'Recomendaciones'
if ($recomendaciones.Count -eq 0) {
    Write-Vineta 'Todo se ve bien desde tu PC. Si internet aún se siente lento, mide la velocidad en fast.com y compárala con tu plan: si es menor, el problema está en el proveedor.'
} else {
    foreach ($texto in ($recomendaciones | Select-Object -Unique)) { Write-Vineta $texto }
}
