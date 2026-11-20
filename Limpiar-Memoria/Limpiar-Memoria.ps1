# Limpiar-Memoria.ps1 - Libera la RAM que no usan los programas de la lista y muestra el antes y el después. Sin administrador.
# Orden del archivo: CHEQUEO INICIAL > CONFIGURACIÓN > VISTA > MÉTODOS REUTILIZABLES > ACCIONES > MAIN (al final, como en Java).

# ════════ CHEQUEO INICIAL ════════

# Si la empresa restringe PowerShell (modo de lenguaje restringido), avisar y no hacer nada.
if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Write-Host '   PowerShell está restringido en este equipo por política de la empresa: esta herramienta no se ejecuta aquí.' -ForegroundColor Red
    return
}

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

# Los programas de la lista abiertos en TU sesión (no los de otros usuarios conectados al mismo PC).
function Obtener-ProgramasDeTuSesion {
    $sesion = (Get-Process -Id $PID).SessionId
    @(Get-Process -Name $Programas -ErrorAction SilentlyContinue | Where-Object SessionId -eq $sesion)
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

# Libera la RAM de cada proceso, reporta cuántos lo lograron y devuelve esos procesos.
function Liberar-RamProgramas($procesos) {
    $limpiados = @($procesos | Where-Object { Liberar-RamProceso $_ })
    Escribir-Linea 'Procesos limpiados' $limpiados.Count 'ok'
    $sinPermiso = $procesos.Count - $limpiados.Count
    if ($sinPermiso) { Escribir-Linea 'Sin permiso' "$sinPermiso (abiertos como administrador)" 'info' }
    $limpiados
}

# Cuánto soltó cada programa: la RAM que tenía al empezar (guardada en $procesos) contra la de ahora.
function Mostrar-QuienSolto($procesos) {
    $ahora = @{}
    Get-Process | ForEach-Object { $ahora[$_.Id] = $_.WorkingSet64 }
    Escribir-Linea 'Lo que soltó cada programa' ''
    $procesos | Group-Object ProcessName | ForEach-Object {
        $antesMB = ($_.Group | Measure-Object WorkingSet64 -Sum).Sum / 1MB
        $ahoraMB = ($_.Group | ForEach-Object { [long]$ahora[$_.Id] } | Measure-Object -Sum).Sum / 1MB   # cerrado = 0
        [pscustomobject]@{ Nombre = '{0} ({1})' -f $_.Name, $_.Count; Antes = $antesMB; Ahora = $ahoraMB; Solto = $antesMB - $ahoraMB }
    } | Where-Object Solto -ge 1 | Sort-Object Solto -Descending | Select-Object -First 8 |
        ForEach-Object { Escribir-Linea "  $($_.Nombre)" ('{0:N0} MB  (de {1:N0} a {2:N0} MB)' -f $_.Solto, $_.Antes, $_.Ahora) 'ok' }
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
    $procesos = Obtener-ProgramasDeTuSesion   # cada proceso guarda la RAM que tenía en este momento

    # 1. Antes, liberar, después.
    Escribir-Titulo 'Memoria'
    Mostrar-Memoria 'Antes'
    $limpiados = Liberar-RamProgramas $procesos
    Start-Sleep -Seconds 2   # dar tiempo a Windows de actualizar sus contadores
    Mostrar-Memoria 'Después'

    # 2. Cuánto se liberó, quién lo soltó y quién usa más ahora.
    Escribir-Titulo 'Resultado'
    Mostrar-RamLiberada $libreAntes
    Mostrar-QuienSolto $limpiados
    Mostrar-TopMemoria

    Escribir-Titulo 'Listo'
}

Main
