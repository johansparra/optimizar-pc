# Limpiar-Memoria-Simple.ps1 - Libera la RAM que no usan los programas de la lista y muestra el antes y el después. Sin administrador.
# Orden del archivo: CONFIGURACIÓN > VISTA > MÉTODOS REUTILIZABLES > ACCIONES > MAIN (al final, como en Java).

# ════════ CONFIGURACIÓN ════════

# Solo se toca a estos programas; nada de Windows, antivirus, VPN ni Zscaler. Nombres sin .exe.
$Programas = 'chrome', 'msedge', 'msedgewebview2', 'firefox', 'brave', 'opera',
    'OUTLOOK', 'olk', 'WINWORD', 'EXCEL', 'POWERPNT', 'ONENOTE', 'MSACCESS',
    'ms-teams', 'Teams', 'lync', 'CiscoCollabHost', 'atmgr', 'Zoom', 'slack',
    'explorer', 'SearchHost', 'StartMenuExperienceHost', 'ShellExperienceHost', 'TextInputHost', 'Widgets',
    'Acrobat', 'AcroRd32', 'Code', 'notepad', 'Spotify', 'WhatsApp', 'Discord'

# ════════ VISTA (todo lo visual está aquí: colores, títulos y barras) ════════

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

# Barra de uso: verde, amarilla desde 80 % y roja desde 90 %.
function Escribir-Barra($nombre, $pct, $detalle) {
    $llenos = [int]($pct / 100 * 30)
    $tipo = if ($pct -ge 90) { 'mal' } elseif ($pct -ge 80) { 'aviso' } else { 'ok' }
    Write-Host ('   {0,-10}' -f $nombre) -NoNewline
    Write-Host ('█' * $llenos) -ForegroundColor $Colores[$tipo] -NoNewline
    Write-Host ('░' * (30 - $llenos)) -ForegroundColor DarkGray -NoNewline
    Write-Host (' {0,3:N0} %   {1}' -f $pct, $detalle)
}

# ════════ MÉTODOS REUTILIZABLES ════════

function Obtener-RamLibreMB {
    (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1KB
}

# Volver a fijar su propio límite hace que Windows le recorte la RAM que no está usando.
# Devuelve $true si lo logró y $false si no hay permiso (programa abierto como administrador).
function Liberar-RamProceso($proceso) {
    try { $proceso.MaxWorkingSet = $proceso.MaxWorkingSet; $true } catch { $false }
}

# ════════ ACCIONES (un método = una tarea) ════════

# Barra con la RAM en uso en este momento.
function Mostrar-Memoria($momento) {
    $os = Get-CimInstance Win32_OperatingSystem
    $usadaKB = $os.TotalVisibleMemorySize - $os.FreePhysicalMemory
    Escribir-Barra $momento (100 * $usadaKB / $os.TotalVisibleMemorySize) ('{0:N1} GB de {1:N1} GB en uso' -f ($usadaKB / 1MB), ($os.TotalVisibleMemorySize / 1MB))
}

function Liberar-RamProgramas {
    $limpiados = 0
    $sinPermiso = 0
    foreach ($proceso in (Get-Process -Name $Programas -ErrorAction SilentlyContinue)) {
        if (Liberar-RamProceso $proceso) { $limpiados++ } else { $sinPermiso++ }
    }
    Escribir-Linea 'Procesos limpiados' $limpiados 'ok'
    if ($sinPermiso) { Escribir-Linea 'Sin permiso' "$sinPermiso (abiertos como administrador)" 'info' }
}

function Mostrar-RamLiberada($libreAntesMB) {
    $liberada = (Obtener-RamLibreMB) - $libreAntesMB
    if ($liberada -ge 50) { Escribir-Linea 'RAM liberada' ('{0:N0} MB' -f $liberada) 'ok' }
    else                  { Escribir-Linea 'RAM liberada' 'poca: tus programas ya usaban poca memoria' 'info' }
}

function Mostrar-TopMemoria {
    Escribir-Linea 'Lo que más RAM usa ahora' ''
    Get-Process | Group-Object ProcessName |
        Select-Object Name, Count, @{ n = 'MB'; e = { ($_.Group | Measure-Object WorkingSet64 -Sum).Sum / 1MB } } |
        Sort-Object MB -Descending | Select-Object -First 5 |
        ForEach-Object { Escribir-Linea ('  {0} ({1})' -f $_.Name, $_.Count) ('{0:N0} MB' -f $_.MB) }
}

# ════════ MAIN ════════

function Main {
    Escribir-Encabezado 'LIMPIAR MEMORIA RAM'
    $libreAntes = Obtener-RamLibreMB

    # 1. Antes, liberar, después.
    Escribir-Titulo 'Memoria'
    Mostrar-Memoria 'Antes'
    Liberar-RamProgramas
    Start-Sleep -Seconds 2   # dar tiempo a Windows de actualizar sus contadores
    Mostrar-Memoria 'Después'

    # 2. Cuánto se liberó y quién usa más ahora.
    Escribir-Titulo 'Resultado'
    Mostrar-RamLiberada $libreAntes
    Mostrar-TopMemoria

    Escribir-Titulo 'Listo'
}

Main
