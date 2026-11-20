<#PSScriptInfo
.VERSION 1.0.0
.GUID e49baf6a-99cc-467b-ad34-0a4460f93c32
.AUTHOR johansparra
.PROJECTURI https://github.com/johansparra/memory
.RELEASENOTES
1.0.0 (2026-11-19): primera versión con este bloque. Estructura por métodos, VISTA, chequeo de PowerShell restringido y bloque de administrador.
#>

<#
.SYNOPSIS
Libera la RAM que no usan los programas de la lista y muestra el antes y el después.
.DESCRIPTION
Doble clic en Limpiar-Memoria.bat. No necesita administrador: solo toca los programas de la lista $Programas abiertos en tu sesión (nada de Windows, antivirus, VPN ni Zscaler).
.NOTES
Orden del archivo: CHEQUEO INICIAL > CONFIGURACIÓN > VISTA > MÉTODOS REUTILIZABLES > ACCIONES > MAIN (al final, como en Java).
Versión y notas de versión: bloque PSScriptInfo de arriba (se mantiene con la skill actualizar-version-scripts).
#>

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

# Barra de uso: verde, amarilla desde 80 % y roja desde 90 %.
function Write-Bar($nombre, $pct, $detalle) {
    $llenos = [int]($pct / 100 * 30)
    $tipo = if ($pct -ge 90) { 'mal' } elseif ($pct -ge 80) { 'aviso' } else { 'ok' }
    Write-Host ('   {0,-10}' -f $nombre) -NoNewline
    Write-Host ('█' * $llenos) -ForegroundColor $Colores[$tipo] -NoNewline
    Write-Host ('░' * (30 - $llenos)) -ForegroundColor DarkGray -NoNewline
    Write-Host (' {0,3:N0} %   {1}' -f $pct, $detalle)
}

# ════════ MÉTODOS REUTILIZABLES ════════

function Get-FreeRamMB {
    (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1KB
}

# Los programas de la lista abiertos en TU sesión (no los de otros usuarios conectados al mismo PC).
function Get-SessionPrograms {
    $sesion = (Get-Process -Id $PID).SessionId
    @(Get-Process -Name $Programas -ErrorAction SilentlyContinue | Where-Object SessionId -eq $sesion)
}

# Volver a fijar su propio límite hace que Windows le recorte la RAM que no está usando.
# Devuelve $true si lo logró y $false si no hay permiso (programa abierto como administrador).
function Clear-ProcessRam($proceso) {
    try { $proceso.MaxWorkingSet = $proceso.MaxWorkingSet; $true } catch { $false }
}

# ════════ ACCIONES (un método = una tarea) ════════

# Barra con la RAM en uso en este momento.
function Show-Memory($momento) {
    $os = Get-CimInstance Win32_OperatingSystem
    $usadaKB = $os.TotalVisibleMemorySize - $os.FreePhysicalMemory
    Write-Bar $momento (100 * $usadaKB / $os.TotalVisibleMemorySize) ('{0:N1} GB de {1:N1} GB en uso' -f ($usadaKB / 1MB), ($os.TotalVisibleMemorySize / 1MB))
}

# Libera la RAM de cada proceso, reporta cuántos lo lograron y devuelve esos procesos.
function Clear-ProgramsRam($procesos) {
    $limpiados = @($procesos | Where-Object { Clear-ProcessRam $_ })
    Write-Line 'Procesos limpiados' $limpiados.Count 'ok'
    $sinPermiso = $procesos.Count - $limpiados.Count
    if ($sinPermiso) { Write-Line 'Sin permiso' "$sinPermiso (abiertos como administrador)" 'info' }
    $limpiados
}

# Cuánto soltó cada programa: la RAM que tenía al empezar (guardada en $procesos) contra la de ahora.
function Show-ReleasedByProgram($procesos) {
    $ahora = @{}
    Get-Process | ForEach-Object { $ahora[$_.Id] = $_.WorkingSet64 }
    Write-Line 'Lo que soltó cada programa' ''
    $procesos | Group-Object ProcessName | ForEach-Object {
        $antesMB = ($_.Group | Measure-Object WorkingSet64 -Sum).Sum / 1MB
        $ahoraMB = ($_.Group | ForEach-Object { [long]$ahora[$_.Id] } | Measure-Object -Sum).Sum / 1MB   # cerrado = 0
        [pscustomobject]@{ Nombre = '{0} ({1})' -f $_.Name, $_.Count; Antes = $antesMB; Ahora = $ahoraMB; Solto = $antesMB - $ahoraMB }
    } | Where-Object Solto -ge 1 | Sort-Object Solto -Descending | Select-Object -First 8 |
        ForEach-Object { Write-Line "  $($_.Nombre)" ('{0:N0} MB  (de {1:N0} a {2:N0} MB)' -f $_.Solto, $_.Antes, $_.Ahora) 'ok' }
}

function Show-FreedRam($libreAntesMB) {
    $liberada = (Get-FreeRamMB) - $libreAntesMB
    if ($liberada -ge 50) { Write-Line 'RAM liberada' ('{0:N0} MB' -f $liberada) 'ok' }
    else                  { Write-Line 'RAM liberada' 'poca: tus programas ya usaban poca memoria' 'info' }
}

function Show-TopMemory {
    Write-Line 'Lo que más RAM usa ahora' ''
    Get-Process | Group-Object ProcessName |
        Select-Object Name, Count, @{ n = 'MB'; e = { ($_.Group | Measure-Object WorkingSet64 -Sum).Sum / 1MB } } |
        Sort-Object MB -Descending | Select-Object -First 5 |
        ForEach-Object { Write-Line ('  {0} ({1})' -f $_.Name, $_.Count) ('{0:N0} MB' -f $_.MB) }
}

# ════════ MAIN ════════

function Main {
    Write-Header 'LIMPIAR MEMORIA RAM'
    $libreAntes = Get-FreeRamMB
    $procesos = Get-SessionPrograms   # cada proceso guarda la RAM que tenía en este momento

    # 1. Antes, liberar, después.
    Write-Title 'Memoria'
    Show-Memory 'Antes'
    $limpiados = Clear-ProgramsRam $procesos
    Start-Sleep -Seconds 2   # dar tiempo a Windows de actualizar sus contadores
    Show-Memory 'Después'

    # 2. Cuánto se liberó, quién lo soltó y quién usa más ahora.
    Write-Title 'Resultado'
    Show-FreedRam $libreAntes
    Show-ReleasedByProgram $limpiados
    Show-TopMemory

    Write-Title 'Listo'
}

Main
