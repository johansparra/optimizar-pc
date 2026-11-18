<#
    Limpiar-Memoria.ps1  -  Libera memoria RAM de tus programas abiertos.
    NO necesita permisos de administrador.

    Cómo funciona
      Le pide a Windows que saque de la RAM la memoria que no están usando los
      programas de la lista $Programas (navegadores, Office, Teams...). Es lo
      mismo que Windows hace por su cuenta cuando le falta memoria.
      No toca nada más: ni Windows, ni antivirus, VPN, Zscaler u otros
      programas de seguridad.
      No compila código, no instala nada y no se conecta a internet.

    Uso
      Doble clic en Limpiar-Memoria.bat
#>

# Programas a los que se les libera memoria. Solo estos; todo lo demás se deja
# como está. Puedes añadir o quitar nombres (sin .exe); acepta comodines (*).
$Programas = @(
    # Navegadores
    'chrome', 'msedge', 'msedgewebview2', 'firefox', 'brave', 'opera'
    # Office, correo y reuniones (CiscoCollabHost y atmgr son Webex)
    'OUTLOOK', 'olk', 'WINWORD', 'EXCEL', 'POWERPNT', 'ONENOTE', 'MSACCESS'
    'ms-teams', 'Teams', 'lync', 'CiscoCollabHost', 'atmgr', 'Zoom', 'slack'
    # Escritorio de Windows (explorador, menú Inicio, búsqueda)
    'explorer', 'SearchHost', 'StartMenuExperienceHost', 'ShellExperienceHost', 'TextInputHost', 'Widgets'
    # Otros
    'Acrobat', 'AcroRd32', 'Code', 'notepad', 'Spotify', 'WhatsApp', 'Discord'
)

function Test-EnLista([string]$Nombre) {
    foreach ($patron in $Programas) { if ($Nombre -like $patron) { return $true } }
    return $false
}

function Get-ProgramasALimpiar {
    # Solo procesos de tu sesión que estén en la lista
    $sesion = (Get-Process -Id $PID).SessionId
    Get-Process | Where-Object { $_.SessionId -eq $sesion -and (Test-EnLista $_.ProcessName) }
}

function Clear-MemoriaProceso($Proceso) {
    # Volver a fijar el límite de memoria que el proceso ya tiene hace que Windows
    # le recorte la RAM que no está usando (igual que EmptyWorkingSet). No cambia
    # ningún ajuste del programa. Si no hay permiso, simplemente no hace nada.
    try {
        $limite = $Proceso.MaxWorkingSet
        if ($null -eq $limite) { return $false }
        $Proceso.MaxWorkingSet = $limite
        return $true
    } catch {
        return $false
    }
}

function Get-Ram {
    $os = Get-CimInstance Win32_OperatingSystem
    $total = [double]$os.TotalVisibleMemorySize * 1KB
    $disponible = [double]$os.FreePhysicalMemory * 1KB
    [pscustomobject]@{
        Total      = $total
        Disponible = $disponible
        EnUso      = $total - $disponible
        Pct        = 100 * ($total - $disponible) / $total
    }
}

function Format-Tamano([double]$Bytes) {
    if ([math]::Abs($Bytes) -ge 1GB) { return '{0:N1} GB' -f ($Bytes / 1GB) }
    if ([math]::Abs($Bytes) -ge 1MB) { return '{0:N0} MB' -f ($Bytes / 1MB) }
    return '{0:N0} KB' -f ($Bytes / 1KB)
}

function Write-Titulo([string]$Texto) {
    $linea = '═' * 62
    Write-Host ''
    Write-Host "  $linea" -ForegroundColor DarkCyan
    Write-Host "   $Texto" -ForegroundColor Cyan
    Write-Host "  $linea" -ForegroundColor DarkCyan
    Write-Host ''
}

function Write-Barra([string]$Etiqueta, [double]$Pct, [string]$Detalle) {
    $ancho = 30
    $llenos = [int][math]::Round([math]::Min(100, [math]::Max(0, $Pct)) / 100 * $ancho)
    $color = if ($Pct -ge 85) { 'Red' } elseif ($Pct -ge 70) { 'Yellow' } else { 'Green' }
    Write-Host ('   {0,-8} ' -f $Etiqueta) -NoNewline
    Write-Host ('█' * $llenos) -ForegroundColor $color -NoNewline
    Write-Host ('░' * ($ancho - $llenos)) -ForegroundColor DarkGray -NoNewline
    Write-Host (' {0,3:N0} %   {1}' -f $Pct, $Detalle)
}

# ─── Programa ────────────────────────────────────────────────────────────────

if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Write-Host ''
    Write-Host '  PowerShell está restringido en este equipo por política de la empresa.' -ForegroundColor Red
    Write-Host '  La limpieza de memoria no se ejecuta aquí.' -ForegroundColor Red
    return
}

$Host.UI.RawUI.WindowTitle = 'Limpiar memoria RAM'
Write-Titulo 'LIMPIAR MEMORIA RAM'
Write-Host '   Liberando memoria de tus programas...' -ForegroundColor DarkGray

$antes = Get-Ram
$procesos = @(Get-ProgramasALimpiar)
$memoriaAntes = @{}
foreach ($p in $procesos) { $memoriaAntes[$p.Id] = $p.WorkingSet64 }

$limpiados = @()
$sinPermiso = 0
foreach ($p in $procesos) {
    if (Clear-MemoriaProceso $p) { $limpiados += $p } else { $sinPermiso++ }
}

Start-Sleep -Seconds 2      # dar tiempo a Windows de actualizar sus contadores
$despues = Get-Ram
$liberado = $despues.Disponible - $antes.Disponible

# Cuánto soltó cada programa (sumando todos sus procesos)
$memoriaAhora = @{}
foreach ($p in Get-Process) { $memoriaAhora[$p.Id] = $p.WorkingSet64 }
$porPrograma = $limpiados | Group-Object ProcessName | ForEach-Object {
    $a = 0; $d = 0
    foreach ($p in $_.Group) {
        $a += $memoriaAntes[$p.Id]
        if ($memoriaAhora.ContainsKey($p.Id)) { $d += $memoriaAhora[$p.Id] }
    }
    [pscustomobject]@{ Nombre = $_.Name; Cantidad = $_.Count; Antes = $a; Ahora = $d; Liberado = $a - $d }
} | Where-Object Liberado -gt 0 | Sort-Object Liberado -Descending | Select-Object -First 8

# ─── Resultado ───────────────────────────────────────────────────────────────

Write-Host ''
$total = Format-Tamano $antes.Total
Write-Barra 'Antes'   $antes.Pct   ('{0} de {1}' -f (Format-Tamano $antes.EnUso), $total)
Write-Barra 'Después' $despues.Pct ('{0} de {1}' -f (Format-Tamano $despues.EnUso), $total)
Write-Host ''
if ($liberado -ge 50MB) {
    Write-Host '   Memoria liberada: ' -NoNewline
    Write-Host (Format-Tamano $liberado) -ForegroundColor Green
} else {
    Write-Host '   Tus programas ya usaban poca memoria; no había mucho que liberar.' -ForegroundColor Yellow
}
$resumen = '   {0} procesos limpiados' -f $limpiados.Count
if ($sinPermiso) { $resumen += ' · {0} sin permiso (abiertos como administrador)' -f $sinPermiso }
Write-Host $resumen -ForegroundColor DarkGray

if ($porPrograma) {
    Write-Host ''
    Write-Host ('   {0,-30}{1,10}{2,10}{3,10}' -f 'Los que más memoria soltaron', 'Antes', 'Ahora', 'Liberado') -ForegroundColor Cyan
    Write-Host ('   ' + '─' * 60) -ForegroundColor DarkGray
    foreach ($fila in $porPrograma) {
        $nombre = $fila.Nombre
        if ($nombre.Length -gt 22) { $nombre = $nombre.Substring(0, 21) + '…' }
        if ($fila.Cantidad -gt 1) { $nombre = '{0} ({1})' -f $nombre, $fila.Cantidad }
        Write-Host ('   {0,-30}{1,10}{2,10}' -f $nombre, (Format-Tamano $fila.Antes), (Format-Tamano $fila.Ahora)) -NoNewline
        Write-Host ('{0,10}' -f (Format-Tamano $fila.Liberado)) -ForegroundColor Green
    }
}

Write-Host ''
Write-Host '   Solo se tocan los programas de la lista; nada de Windows, antivirus ni VPN.' -ForegroundColor DarkGray
Write-Host '   Es normal que la memoria vuelva a subir a medida que usas los programas.' -ForegroundColor DarkGray
