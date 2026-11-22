<#PSScriptInfo
.VERSION 1.1.0
.GUID e49baf6a-99cc-467b-ad34-0a4460f93c32
.AUTHOR johansparra
.PROJECTURI https://github.com/johansparra/optimizar-pc
.RELEASENOTES
1.1.0 (2026-11-22): deja un log de cada ejecución en la carpeta log\, con la función donde pasó cada cosa. El nivel se elige en $NivelLog (INFO por defecto; DEBUG anota qué programas encontró y cuáles no se dejaron limpiar). Guarda los de hoy y ayer, máximo 3 por día y 10 MB por archivo.
#>

<#
.SYNOPSIS
Libera la RAM que no usan los programas de la lista y muestra el antes y el después.
.DESCRIPTION
Doble clic en Limpiar-Memoria.bat. No necesita administrador: solo toca los programas de la lista $Programas abiertos en tu sesión (nada de Windows, antivirus, VPN ni Zscaler). Cada ejecución deja un log en la carpeta log\.
.NOTES
Orden del archivo: CHEQUEO INICIAL > CONFIGURACIÓN > LOG > VISTA > MÉTODOS REUTILIZABLES > ACCIONES > MAIN (al final, como en Java).
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

# Solo se toca a estos programas; nada de Windows, antivirus, VPN ni Zscaler. Nombres sin .exe.
$Programas = 'chrome', 'msedge', 'msedgewebview2', 'firefox', 'brave', 'opera',
    'OUTLOOK', 'olk', 'WINWORD', 'EXCEL', 'POWERPNT', 'ONENOTE', 'MSACCESS',
    'ms-teams', 'Teams', 'lync', 'CiscoCollabHost', 'atmgr', 'Zoom', 'slack',
    'explorer', 'SearchHost', 'StartMenuExperienceHost', 'ShellExperienceHost', 'TextInputHost', 'Widgets',
    'Acrobat', 'AcroRd32', 'Code', 'notepad', 'Spotify', 'WhatsApp', 'Discord'

$NivelLog   = 'INFO'          # log en la carpeta log\: DEBUG, INFO, WARN o ERROR (DEBUG anota qué programas encontró y cuáles no se dejaron: solo para revisar una falla)
$PrefijoLog = 'limpiar-mem'   # nombre de los archivos de log

# ════════ LOG (idéntico en los 4 scripts: si lo cambias, cópialo igual en los demás) ════════

# Un archivo por ejecución en la carpeta log\ junto al .ps1. Se guardan los de hoy y ayer, máximo
# $LogPorDia por día. Si no se puede crear, el script sigue igual, solo que sin log.
$LogPorDia  = 3    # archivos que se guardan por día
$LogMaxMB   = 10   # al llegar a este tamaño se dejan de anotar las líneas DEBUG (las demás siguen)
$Niveles    = @{ DEBUG = 0; INFO = 1; WARN = 2; ERROR = 3 }
$script:ArchivoLog = $null   # no se llama $Log: en PowerShell $log y $Log son la misma variable

# Abre el log de esta ejecución, anota el encabezado y borra los logs viejos.
function Start-Log {
    $script:LogInicio = Get-Date
    $script:LogLleno  = $false
    if ($Niveles.Keys -notcontains $NivelLog) {
        Write-Line 'Log' "el nivel '$NivelLog' no existe; se usa INFO" -tipo 'aviso'
        $script:NivelLog = 'INFO'
    }
    $carpeta = Join-Path $PSScriptRoot 'log'
    try {
        $null = New-Item $carpeta -ItemType Directory -Force -ErrorAction Stop
        $ruta = Join-Path $carpeta ('{0}-{1:yyyy-MM-dd_HH-mm-ss}.log' -f $PrefijoLog, $script:LogInicio)
        $script:ArchivoLog = New-Object IO.StreamWriter($ruta, $true, (New-Object Text.UTF8Encoding($true)))
        $script:ArchivoLog.AutoFlush = $true   # cada línea queda en el disco aunque se cierre la ventana a mitad
    } catch {
        $script:ArchivoLog = $null
        Write-Line 'Log' "no se pudo crear, se sigue sin log: $($_.Exception.Message)" -tipo 'aviso'
        return
    }
    $os      = Get-CimInstance Win32_OperatingSystem
    $version = Select-String -LiteralPath $PSCommandPath -Pattern '^\.VERSION (.+)' | Select-Object -First 1 | ForEach-Object { $_.Matches[0].Groups[1].Value }
    $admin   = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $esAdmin = if ($admin) { 'sí' } else { 'no' }
    Write-LogLine INFO ('{0} {1} | admin: {2} | nivel: {3} | {4} {5} | PowerShell {6}' -f (Split-Path $PSCommandPath -Leaf), $version, $esAdmin, $NivelLog, $os.Caption, $os.Version, $PSVersionTable.PSVersion)
    Remove-OldLog $carpeta
}

# Deja los logs de hoy y ayer, los $LogPorDia más nuevos de cada día. Solo toca archivos con el nombre exacto de un log.
function Remove-OldLog($carpeta) {
    $ayer   = (Get-Date).AddDays(-1).ToString('yyyy-MM-dd')
    $patron = '^{0}-(\d{{4}}-\d\d-\d\d)_\d\d-\d\d-\d\d\.log$' -f [regex]::Escape($PrefijoLog)
    $porDia = Get-ChildItem -LiteralPath $carpeta -File | Where-Object Name -Match $patron | Group-Object { $_.Name -replace $patron, '$1' }
    foreach ($dia in $porDia) {
        $sobran = if ($dia.Name -lt $ayer) { $dia.Group } else { $dia.Group | Sort-Object Name -Descending | Select-Object -Skip $LogPorDia }
        foreach ($archivo in $sobran) {
            try   { Remove-Item -LiteralPath $archivo.FullName -ErrorAction Stop; Write-LogLine DEBUG "Log viejo borrado: $($archivo.Name)" }
            catch { Write-LogLine DEBUG "Log viejo que no se pudo borrar: $($archivo.Name): $($_.Exception.Message)" }
        }
    }
}

# Anota una línea si su nivel llega a $NivelLog. La columna del medio es la cadena de funciones que
# llevó hasta aquí (sin Main ni las de VISTA y LOG), para saber dónde pasó.
function Write-LogLine($nivel, $texto) {
    if (-not $script:ArchivoLog -or $Niveles[$nivel] -lt $Niveles[$NivelLog]) { return }
    if ($nivel -eq 'DEBUG' -and $script:ArchivoLog.BaseStream.Length -ge $LogMaxMB * 1MB) {
        if (-not $script:LogLleno) { $script:LogLleno = $true; Write-LogLine WARN "El log llegó a $LogMaxMB MB: ya no se anotan las líneas DEBUG" }
        return
    }
    $cadena = @(Get-PSCallStack | Select-Object -Skip 1 -ExpandProperty FunctionName |
        Where-Object { $_ -notmatch '^(Write-|Main$|<ScriptBlock>)' })
    [array]::Reverse($cadena)
    $donde = if ($cadena) { $cadena -join '>' } else { 'Main' }
    $linea = '{0:yyyy-MM-dd HH:mm:ss.fff} [{1,-5}] {2} | {3}' -f (Get-Date), $nivel, $donde, ($texto -replace '\r?\n', ' ')
    # Si escribir falla (por ejemplo, el disco se llenó), se deja de escribir el log y el script sigue.
    try   { $script:ArchivoLog.WriteLine($linea) }
    catch { $script:ArchivoLog = $null; Write-Line 'Log' "se dejó de escribir: $($_.Exception.Message)" -tipo 'aviso' }
}

# Nivel del log para cada tipo de la VISTA: aviso (amarillo) = WARN, mal (rojo) = ERROR, el resto INFO.
function Get-LogLevel($tipo) {
    switch ($tipo) { 'aviso' { 'WARN' } 'mal' { 'ERROR' } default { 'INFO' } }
}

# Al final: anota en DEBUG los errores de PowerShell que hubo (con su función y línea), cuánto duró, y cierra
# el archivo. Main no va dentro de try: así un error sale en rojo y el script sigue, igual que sin log.
# En DEBUG salen también los errores que el script ignora a propósito (temporales sin permiso, programas cerrados).
function Stop-Log {
    if (-not $script:ArchivoLog) { return }
    $errores = @($Error)   # el más nuevo primero; PowerShell guarda máximo 256
    [array]::Reverse($errores)
    foreach ($e in $errores) { Write-LogLine DEBUG ('Error de PowerShell: {0} | {1}' -f $e.Exception.Message, ($e.ScriptStackTrace -replace '\r?\n', ' <- ')) }
    Write-LogLine INFO ('Fin ({0:N0} s)' -f ((Get-Date) - $script:LogInicio).TotalSeconds)
    try { $script:ArchivoLog.Dispose() } catch { Write-Verbose "No se pudo cerrar el log: $_" }
    $script:ArchivoLog = $null
}

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
    Write-LogLine INFO "=== $texto ==="
}

# Una línea del reporte: qué se hizo a la izquierda, resultado a la derecha con el color de su tipo.
# También va al log, con el nivel que corresponde a su tipo.
function Write-Line($nombre, $resultado, $tipo = 'normal') {
    Write-Host ('   {0,-32} ' -f $nombre) -NoNewline   # el espacio final separa aunque el nombre sea largo
    Write-Host $resultado -ForegroundColor $Colores[$tipo]
    Write-LogLine (Get-LogLevel $tipo) ((@("$nombre".Trim(), "$resultado") -ne '') -join ': ')
}

# Barra de uso: verde, amarilla desde 80 % y roja desde 90 %.
function Write-Bar($nombre, $pct, $detalle) {
    $llenos = [int]($pct / 100 * 30)
    $tipo = if ($pct -ge 90) { 'mal' } elseif ($pct -ge 80) { 'aviso' } else { 'ok' }
    Write-Host ('   {0,-10}' -f $nombre) -NoNewline
    Write-Host ('█' * $llenos) -ForegroundColor $Colores[$tipo] -NoNewline
    Write-Host ('░' * (30 - $llenos)) -ForegroundColor DarkGray -NoNewline
    Write-Host (' {0,3:N0} %   {1}' -f $pct, $detalle)
    Write-LogLine INFO ('{0}: {1:N0} %, {2}' -f $nombre, $pct, $detalle)
}

# ════════ MÉTODOS REUTILIZABLES ════════

function Get-FreeRamMB {
    (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1KB
}

# Los programas de la lista abiertos en TU sesión (no los de otros usuarios conectados al mismo PC).
function Get-SessionProgram {
    $sesion = (Get-Process -Id $PID).SessionId
    $procesos = @(Get-Process -Name $Programas -ErrorAction SilentlyContinue | Where-Object SessionId -eq $sesion)
    Write-LogLine DEBUG ('Abiertos en tu sesión: {0} procesos ({1})' -f $procesos.Count, (($procesos.ProcessName | Sort-Object -Unique) -join ', '))
    $procesos
}

# Volver a fijar su propio límite hace que Windows le recorte la RAM que no está usando.
# Devuelve $true si lo logró y $false si no hay permiso (programa abierto como administrador).
function Clear-ProcessRam($proceso) {
    try { $proceso.MaxWorkingSet = $proceso.MaxWorkingSet; $true }
    catch { Write-LogLine DEBUG "No se dejó $($proceso.ProcessName) ($($proceso.Id)): $($_.Exception.Message)"; $false }
}

# ════════ ACCIONES (un método = una tarea) ════════

# Barra con la RAM en uso en este momento.
function Show-Memory($momento) {
    $os = Get-CimInstance Win32_OperatingSystem
    $usadaKB = $os.TotalVisibleMemorySize - $os.FreePhysicalMemory
    Write-Bar $momento (100 * $usadaKB / $os.TotalVisibleMemorySize) -detalle ('{0:N1} GB de {1:N1} GB en uso' -f ($usadaKB / 1MB), ($os.TotalVisibleMemorySize / 1MB))
}

# Libera la RAM de cada proceso, reporta cuántos lo lograron y devuelve esos procesos.
function Clear-ProgramsRam($procesos) {
    $limpiados = @($procesos | Where-Object { Clear-ProcessRam $_ })
    Write-Line 'Procesos limpiados' $limpiados.Count -tipo 'ok'
    $sinPermiso = $procesos.Count - $limpiados.Count
    if ($sinPermiso) { Write-Line 'Sin permiso' "$sinPermiso (abiertos como administrador)" -tipo 'info' }
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
        ForEach-Object { Write-Line "  $($_.Nombre)" ('{0:N0} MB  (de {1:N0} a {2:N0} MB)' -f $_.Solto, $_.Antes, $_.Ahora) -tipo 'ok' }
}

function Show-FreedRam($libreAntesMB) {
    $liberada = (Get-FreeRamMB) - $libreAntesMB
    if ($liberada -ge 50) { Write-Line 'RAM liberada' ('{0:N0} MB' -f $liberada) -tipo 'ok' }
    else                  { Write-Line 'RAM liberada' 'poca: tus programas ya usaban poca memoria' -tipo 'info' }
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
    Start-Log
    $libreAntes = Get-FreeRamMB
    $procesos = Get-SessionProgram   # cada proceso guarda la RAM que tenía en este momento

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

# Sin try a propósito: si algo falla sale en rojo y el resto sigue, igual que antes. Stop-Log cierra el log.
Main
Stop-Log
