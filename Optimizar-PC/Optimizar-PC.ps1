<#PSScriptInfo
.VERSION 1.4.1
.GUID 81b2e606-23df-4e75-8725-5df78a0609fc
.AUTHOR johansparra
.PROJECTURI https://github.com/johansparra/optimizar-pc
.RELEASENOTES
1.4.1 (2026-11-22): en el log, la columna de la función ya no muestra comandos de Windows a mitad de camino (por ejemplo Get-PhysicalDisk<Process>), solo las funciones del script. El script hace lo mismo.
#>

<#
.SYNOPSIS
Borra temporales y cachés de tu usuario, reporta qué borró y revisa el equipo (espacio, salud de discos y batería).
.DESCRIPTION
Doble clic en Optimizar-PC.bat: limpieza. Clic derecho > Ejecutar como administrador: limpieza + mantenimiento de Windows. Cada ejecución deja un log en la carpeta log\.
.NOTES
Orden del archivo: CHEQUEO INICIAL > CONFIGURACIÓN > LOG > VISTA > MÉTODOS REUTILIZABLES > REVISIÓN > LIMPIEZA > MANTENIMIENTO (solo admin) > MAIN (al final, como en Java).
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

$HorasMinimas = 24                              # los temporales más nuevos que esto no se tocan
$Local        = $env:LOCALAPPDATA
$Unidad       = $env:SystemDrive.TrimEnd(':')   # normalmente C
$NivelLog     = 'INFO'                          # log en la carpeta log\: DEBUG, INFO, WARN o ERROR (DEBUG anota cada archivo borrado: solo para revisar una falla)
$PrefijoLog   = 'op-pc'                         # nombre de los archivos de log

# Contadores del resumen final; los suma Remove-OldFile.
# ($script: = variable compartida por todo el archivo, como un atributo de clase en Java)
$script:TotalArchivos = 0
$script:TotalBytes    = 0

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
# llevó hasta aquí (sin Main, las de VISTA y LOG ni bloques como <ScriptBlock> o Get-PhysicalDisk<Process>), para saber dónde pasó.
function Write-LogLine($nivel, $texto) {
    if (-not $script:ArchivoLog -or $Niveles[$nivel] -lt $Niveles[$NivelLog]) { return }
    if ($nivel -eq 'DEBUG' -and $script:ArchivoLog.BaseStream.Length -ge $LogMaxMB * 1MB) {
        if (-not $script:LogLleno) { $script:LogLleno = $true; Write-LogLine WARN "El log llegó a $LogMaxMB MB: ya no se anotan las líneas DEBUG" }
        return
    }
    $cadena = @(Get-PSCallStack | Select-Object -Skip 1 -ExpandProperty FunctionName |
        Where-Object { $_ -notmatch '^(Write-|Main$)|<' })
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

# Borra los archivos y las subcarpetas vacías con más de $horas de antigüedad, y reporta cuántos borró,
# cuánto pesaban y cuántos estaban en uso. Los que están en uso se dejan.
function Remove-OldFile($nombre, $rutas, $horas = 0) {
    $limite = (Get-Date).AddHours(-$horas)
    # La lista se toma antes de borrar: al borrar un archivo, su carpeta queda con fecha de ahora.
    $viejos = @(Get-Item $rutas -Force -ErrorAction SilentlyContinue |
        Get-ChildItem -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object LastWriteTime -lt $limite)
    Write-LogLine DEBUG ('Busca en {0} lo anterior a {1:yyyy-MM-dd HH:mm}: {2} elementos' -f ($rutas -join '; '), $limite, $viejos.Count)
    $archivos = 0
    $bytes = 0
    $enUso = 0
    foreach ($archivo in ($viejos | Where-Object { -not $_.PSIsContainer })) {
        try {
            Remove-Item -LiteralPath $archivo.FullName -Force -ErrorAction Stop
            $archivos++
            $bytes += $archivo.Length
            Write-LogLine DEBUG ('Borrado {0} ({1:N1} KB)' -f $archivo.FullName, ($archivo.Length / 1KB))
        } catch {
            $enUso++
            Write-LogLine DEBUG "No se pudo borrar $($archivo.FullName): $($_.Exception.Message)"
        }
    }
    Remove-EmptyFolder $viejos
    $script:TotalArchivos += $archivos
    $script:TotalBytes    += $bytes
    $texto = if ($archivos) { '{0} archivos, {1:N1} MB' -f $archivos, ($bytes / 1MB) } else { 'nada' }
    if ($enUso) { $texto += " · $enUso en uso (se dejan)" }
    Write-Line $nombre $texto -tipo $(if ($archivos) { 'ok' } else { 'info' })
}

# Borra las carpetas de la lista que quedaron vacías, de la más profunda a la menos profunda.
# Nunca toca accesos directos de carpeta (junctions/enlaces), para no salirse de la carpeta que se limpia.
function Remove-EmptyFolder($items) {
    $items | Where-Object { $_.PSIsContainer -and -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) } |
        Sort-Object { $_.FullName.Length } -Descending |
        ForEach-Object {
            $carpeta = $_   # dentro del catch, $_ ya es el error
            try { $carpeta.Delete() } catch { Write-LogLine DEBUG "Carpeta que se deja: $($carpeta.FullName)" }   # Delete() sin $true falla solo si no está vacía
        }
}

# Borra la caché de un programa solo si está instalado y cerrado.
function Remove-CacheIfClosed($nombre, $proceso, $rutas) {
    if (-not (Get-Item $rutas -Force -ErrorAction SilentlyContinue)) { Write-Line $nombre 'no instalado' -tipo 'info'; return }
    if (Get-Process $proceso -ErrorAction SilentlyContinue) { Write-Line $nombre 'se salta: el programa está abierto' -tipo 'aviso'; return }
    Remove-OldFile $nombre $rutas
}

# Carpetas de caché de los navegadores hechos sobre Chrome (Chrome, Edge, Brave), en todos sus perfiles.
# No incluye contraseñas, historial, cookies ni sesiones.
function Get-ChromiumCachePath($datosUsuario) {
    "$datosUsuario\*\Cache", "$datosUsuario\*\Code Cache", "$datosUsuario\*\GPUCache"
}

# Ejecuta una herramienta de Windows, espera a que termine y reporta si salió bien.
function Invoke-Tool($nombre, $programa, $argumentos) {
    Write-Line $nombre 'ejecutando...' -tipo 'info'
    Write-LogLine DEBUG "Comando: $programa $argumentos"
    $proceso = Start-Process $programa $argumentos -Wait -PassThru -NoNewWindow
    if ($proceso.ExitCode -eq 0) { Write-Line $nombre 'OK' -tipo 'ok' }
    else                         { Write-Line $nombre "terminó con código $($proceso.ExitCode)" -tipo 'mal' }
}

function Get-FreeSpaceMB {
    (Get-PSDrive $Unidad).Free / 1MB
}

# $true si el script se abrió con "Ejecutar como administrador" (funciona con Windows en cualquier idioma).
function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# El Administrador de tareas guarda en "StartupApproved" lo que desactivas: primer byte impar = desactivado.
function Test-StartupDisabled($claveAprobados, $nombre) {
    $valor = (Get-ItemProperty $claveAprobados -Name $nombre -ErrorAction SilentlyContinue).$nombre
    [bool]($valor -and ($valor[0] % 2 -eq 1))
}

# Programas habilitados de una clave "Run" del registro.
function Get-RegistryStartup($clave, $claveAprobados) {
    (Get-Item $clave -ErrorAction SilentlyContinue).Property |
        Where-Object { -not (Test-StartupDisabled $claveAprobados $_) }
}

# Programas habilitados de una carpeta "Inicio" (accesos directos).
function Get-FolderStartup($carpeta, $claveAprobados) {
    Get-ChildItem $carpeta -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne 'desktop.ini' -and -not (Test-StartupDisabled $claveAprobados $_.Name) } |
        ForEach-Object BaseName
}

# ════════ REVISIÓN (un método = un dato) ════════

function Show-Disk {
    $disco = Get-PSDrive $Unidad
    $total = $disco.Used + $disco.Free
    Write-Bar "Disco $Unidad" (100 * $disco.Used / $total) -detalle ('{0:N1} GB libres de {1:N1} GB' -f ($disco.Free / 1GB), ($total / 1GB))
}

# Salud de cada disco según su propio chip (SMART): si está sano, cuánto se ha desgastado el SSD y su
# temperatura. Solo consulta (no pide admin). Avisa a tiempo si un disco empieza a fallar.
function Show-DiskHealth {
    Write-Line 'Salud de los discos' ''
    Get-PhysicalDisk | Where-Object FriendlyName -notmatch 'Virtual' | ForEach-Object {
        $rc = $_ | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
        $detalle = switch ($_.HealthStatus) { 'Healthy' { 'sano' } 'Warning' { 'atención: respáldalo' } default { "$($_.HealthStatus): respáldalo ya" } }
        if ($null -ne $rc.Wear) { $detalle += ", desgaste $($rc.Wear) %" }
        if ($rc.Temperature)    { $detalle += ", $($rc.Temperature) °C" }
        $tipo = switch ($_.HealthStatus) { 'Healthy' { 'ok' } 'Warning' { 'aviso' } default { 'mal' } }
        Write-Line "  $($_.FriendlyName)" $detalle -tipo $tipo
    }
}

# TRIM: Windows le avisa al disco SSD qué espacio quedó libre, para que siga rápido. Windows 11 lo trae
# activado; aquí solo se consulta (no pide admin). Como admin, Enable-Trim lo activa antes de esta revisión.
function Show-Trim {
    $estado = fsutil behavior query DisableDeleteNotify | Select-String 'DisableDeleteNotify\s*=\s*(\d)' | Select-Object -First 1
    if (-not $estado)                                 { Write-Line 'TRIM (discos SSD)' 'no se pudo consultar' -tipo 'info' }
    elseif ($estado.Matches.Groups[1].Value -eq '0') { Write-Line 'TRIM (discos SSD)' 'activado' -tipo 'ok' }
    else { Write-Line 'TRIM (discos SSD)' 'desactivado: abre el .bat como administrador y se activa' -tipo 'aviso' }
}

# Salud de la batería (solo en laptops): cuánta carga aguanta hoy frente a la que traía nueva.
# En un equipo de escritorio no hay batería y no muestra nada.
function Show-Battery {
    $full   = Get-CimInstance BatteryFullChargedCapacity -Namespace ROOT/WMI -ErrorAction SilentlyContinue
    $design = Get-CimInstance BatteryStaticData -Namespace ROOT/WMI -ErrorAction SilentlyContinue
    if (-not $full -or -not $design) { return }
    $cargaHoy   = ($full   | Measure-Object FullChargedCapacity -Sum).Sum
    $cargaNueva = ($design | Measure-Object DesignedCapacity -Sum).Sum
    if (-not $cargaNueva) { return }
    $salud = [int](100 * $cargaHoy / $cargaNueva)
    $tipo = if ($salud -lt 60) { 'mal' } elseif ($salud -lt 80) { 'aviso' } else { 'ok' }
    Write-Line 'Salud de la batería' "$salud % de la capacidad original" -tipo $tipo
}

function Show-DaysSinceRestart {
    $dias = ((Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime).Days
    if ($dias -ge 7) { Write-Line 'Días sin reiniciar' "$dias (reinicia con Inicio > Reiniciar)" -tipo 'aviso' }
    else             { Write-Line 'Días sin reiniciar' $dias -tipo 'ok' }
}

function Show-PendingRestart {
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        Write-Line 'Actualizaciones' 'esperando un reinicio' -tipo 'aviso'
    } else {
        Write-Line 'Actualizaciones' 'sin reinicio pendiente' -tipo 'ok'
    }
}

# Igual que Administrador de tareas > Aplicaciones de arranque, solo las habilitadas.
function Show-StartupProgram {
    $aprobados = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
    $programas = @(
        Get-RegistryStartup 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'             "HKCU:\$aprobados\Run"
        Get-RegistryStartup 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'             "HKLM:\$aprobados\Run"
        Get-RegistryStartup 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' "HKLM:\$aprobados\Run32"
        Get-FolderStartup ([Environment]::GetFolderPath('Startup'))       "HKCU:\$aprobados\StartupFolder"
        Get-FolderStartup ([Environment]::GetFolderPath('CommonStartup')) "HKLM:\$aprobados\StartupFolder"
    ) | Sort-Object -Unique
    $tipo = if ($programas.Count -gt 8) { 'aviso' } else { 'ok' }
    Write-Line 'Arrancan con Windows' ('{0} programas habilitados' -f $programas.Count) -tipo $tipo
    $programas | ForEach-Object { Write-Line '' $_ }
}

# Lo que se borró en total (archivos contados) y lo que realmente ganó el disco (incluye Papelera y Liberador).
function Show-Summary($libreAntes) {
    Write-Line 'Archivos borrados' ('{0} ({1:N1} MB)' -f $script:TotalArchivos, ($script:TotalBytes / 1MB)) -tipo 'ok'
    Write-Line "Espacio ganado en $Unidad" ('{0:N0} MB' -f [math]::Max(0, (Get-FreeSpaceMB) - $libreAntes)) -tipo 'ok'
}

# ════════ LIMPIEZA (un método = una tarea) ════════

function Clear-Trash {
    $elementos = (New-Object -ComObject Shell.Application).NameSpace(10).Items().Count
    if ($elementos -eq 0) { Write-Line 'Papelera' 'ya estaba vacía' -tipo 'info'; return }
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Line 'Papelera' "$elementos elementos vaciados" -tipo 'ok'
}

function Clear-Temp {
    Remove-OldFile 'Temporales (%TEMP%)' $env:TEMP -horas $HorasMinimas
}

function Clear-InternetCache {
    Remove-OldFile 'Caché de internet (Windows)' "$Local\Microsoft\Windows\INetCache" -horas $HorasMinimas
}

function Clear-ChromeCache {
    Remove-CacheIfClosed 'Caché de Chrome' 'chrome' -rutas (Get-ChromiumCachePath "$Local\Google\Chrome\User Data")
}

function Clear-EdgeCache {
    Remove-CacheIfClosed 'Caché de Edge' 'msedge' -rutas (Get-ChromiumCachePath "$Local\Microsoft\Edge\User Data")
}

function Clear-BraveCache {
    Remove-CacheIfClosed 'Caché de Brave' 'brave' -rutas (Get-ChromiumCachePath "$Local\BraveSoftware\Brave-Browser\User Data")
}

function Clear-FirefoxCache {
    Remove-CacheIfClosed 'Caché de Firefox' 'firefox' -rutas "$Local\Mozilla\Firefox\Profiles\*\cache2"
}

function Clear-TeamsCache {
    Remove-CacheIfClosed 'Caché de Teams' 'ms-teams' -rutas "$Local\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams"
}

# Miniaturas e íconos del Explorador; Windows los vuelve a crear.
function Clear-ThumbnailCache {
    Remove-OldFile 'Miniaturas del Explorador' "$Local\Microsoft\Windows\Explorer\*.db"
}

# Solo admin (las opciones se guardan en HKLM). Marca en el perfil 1 del Liberador todas las opciones menos
# Descargas, que borraría tus archivos descargados. Marcarlas a mano en la ventana nunca las deja todas,
# porque Windows solo muestra las que tienen algo que limpiar en ese momento.
function Set-DiskCleanupOption {
    $marcadas = 0
    $fallidas = 0
    foreach ($opcion in Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches') {
        $valor = if ($opcion.PSChildName -eq 'DownloadsFolder') { 0 } else { 2 }   # 2 = marcada, 0 = no
        try {
            $null = New-ItemProperty -LiteralPath $opcion.PSPath -Name StateFlags0001 -Value $valor -PropertyType DWord -Force -ErrorAction Stop
            if ($valor) { $marcadas++ }
        } catch {
            $fallidas++
            Write-LogLine DEBUG "Sin permiso en $($opcion.PSChildName): $($_.Exception.Message)"
        }
    }
    $texto = "$marcadas marcadas (todas menos Descargas)"
    if ($fallidas) { $texto += " · $fallidas sin permiso" }
    Write-Line 'Opciones del Liberador' $texto -tipo $(if ($fallidas) { 'aviso' } else { 'ok' })
}

# Liberador de espacio de Windows con las opciones guardadas antes con "cleanmgr /sageset:1".
# No pide admin: sin admin limpia solo lo que tu usuario puede borrar. Si nunca se configuró, no hace nada.
# cleanmgr abre procesos aparte y su ventana se cierra antes de terminar; con Start-Process -Wait el
# script se quedaba colgado. Se lanza y se espera a que no quede ningún cleanmgr, con un tope de 3 min
# para no bloquear nunca: si tarda más, sigue solo en segundo plano y el script continúa.
function Invoke-DiskCleanup {
    Write-Line 'Liberador de espacio' 'ejecutando...' -tipo 'info'
    $libreAntes = Get-FreeSpaceMB
    $reloj = [Diagnostics.Stopwatch]::StartNew()
    Write-LogLine DEBUG 'Comando: cleanmgr.exe /sagerun:1'
    Start-Process cleanmgr.exe '/sagerun:1'
    $limite = (Get-Date).AddMinutes(3)
    do { Start-Sleep -Seconds 2 } while ((Get-Process -Name cleanmgr -ErrorAction SilentlyContinue) -and (Get-Date) -lt $limite)
    # Segundos y MB liberados en el disco del sistema: la prueba de que hizo algo (pocos segundos y 0 MB = no había nada que limpiar).
    $detalle = '{0:N0} s, {1:N0} MB liberados' -f $reloj.Elapsed.TotalSeconds, [math]::Max(0, (Get-FreeSpaceMB) - $libreAntes)
    if (Get-Process -Name cleanmgr -ErrorAction SilentlyContinue) { Write-Line 'Liberador de espacio' "sigue en segundo plano tras $detalle (el script continúa)" -tipo 'info' }
    else { Write-Line 'Liberador de espacio' "OK ($detalle)" -tipo 'ok' }
}

# ════════ MANTENIMIENTO (solo administrador: Main los salta si no lo eres) ════════

# Temporales de Windows (C:\Windows\Temp). Sin admin Windows ni siquiera deja ver la carpeta.
function Clear-WindowsTemp {
    Remove-OldFile 'Temporales de Windows' "$env:WINDIR\Temp" -horas $HorasMinimas
}

# --- Solo para tu PC personal ---------------------------------------------------------------
# Estos borran rastros de uso (informes de errores, historial, cookies, recientes). En un PC de
# empresa el antivirus lo puede ver como "borrado de evidencia"; por eso solo corren como admin,
# y en la laptop del banco no tienes admin.

# Volcados de programas que se cerraron con error, e informes pendientes de enviar a Microsoft.
function Clear-ErrorReport {
    Remove-OldFile 'Informes de errores' "$Local\CrashDumps", "$Local\Microsoft\Windows\WER\ReportQueue"
}

# Historial del antiguo Internet Explorer / Explorador de Windows.
function Clear-WindowsHistory {
    Remove-OldFile 'Historial de Windows' "$Local\Microsoft\Windows\History"
}

# Cookies del antiguo Internet Explorer (en Windows 11 casi siempre está vacía).
function Clear-WindowsCookie {
    Remove-OldFile 'Cookies de Windows' "$env:APPDATA\Microsoft\Windows\Cookies"
}

# Archivos recientes del Explorador. También borra lo anclado en las listas de la barra de tareas.
function Clear-RecentFile {
    Remove-OldFile 'Archivos recientes' "$env:APPDATA\Microsoft\Windows\Recent"
}
# ----------------------------------------------------------------------------------------------

# Repara archivos de Windows dañados: DISM arregla el almacén de componentes (WinSxS) y luego sfc usa
# ese almacén sano para reponer los archivos del sistema. Tarda varios minutos; por eso Main pregunta al inicio.
function Confirm-WindowsRepair {
    $respuesta = Read-Host '   ¿Reparar también archivos de Windows (DISM y sfc)? Tarda varios minutos (S/N)'
    Write-LogLine INFO "Reparar Windows: respondió '$respuesta'"
    $respuesta -match '^\s*s'
}

function Repair-Windows {
    Invoke-Tool 'DISM reparar imagen' 'Dism.exe' -argumentos '/Online /Cleanup-Image /RestoreHealth'
    Invoke-Tool 'Comprobar archivos (sfc)' 'sfc.exe' -argumentos '/scannow'
}

# DISM: borra versiones viejas de actualizaciones de Windows (carpeta WinSxS). Tarda varios minutos.
function Clear-ComponentStore {
    Invoke-Tool 'DISM (WinSxS)' 'Dism.exe' -argumentos '/Online /Cleanup-Image /StartComponentCleanup'
}

# Activa TRIM en los SSD. Windows 11 ya lo trae activado: si ya lo estaba, no cambia nada.
function Enable-Trim {
    Invoke-Tool 'Activar TRIM' 'fsutil.exe' -argumentos 'behavior set DisableDeleteNotify 0'
}

# Desfragmenta los discos normales y hace TRIM en los SSD (todos los discos del equipo).
function Optimize-Disk {
    Invoke-Tool 'Optimizar discos' 'defrag.exe' -argumentos '/C /O'
}

# ════════ MAIN ════════

function Main {
    Write-Header 'OPTIMIZAR PC'
    Start-Log

    # 1. Primero: ¿con qué permisos corre? Eso decide qué se puede hacer.
    $esAdmin = Test-Admin
    if ($esAdmin) { Write-Line 'Modo' 'administrador: limpieza + mantenimiento' -tipo 'ok' }
    else          { Write-Line 'Modo' 'normal: solo limpieza (el mantenimiento pide admin)' -tipo 'info' }
    # La única pregunta va al principio (solo admin); el resto corre sin interrupciones.
    $reparar = $esAdmin -and (Confirm-WindowsRepair)
    $libreAntes = Get-FreeSpaceMB

    # 2. Limpieza. Como admin, antes del Liberador se marcan todas sus opciones (menos Descargas),
    #    para que al ejecutarlo limpie todo.
    Write-Title 'Limpieza'
    Clear-Trash
    Clear-Temp
    Clear-InternetCache
    Clear-ChromeCache
    Clear-EdgeCache
    Clear-BraveCache
    Clear-FirefoxCache
    Clear-TeamsCache
    Clear-ThumbnailCache
    if ($esAdmin) { Set-DiskCleanupOption }
    Invoke-DiskCleanup

    # 3. Mantenimiento: primero reparar Windows (DISM y sfc necesitan un almacén de componentes completo,
    #    antes de que Clear-ComponentStore lo recorte), luego borrar, y al final optimizar el disco ya limpio.
    #    Optimize-Disk va último porque reorganiza el espacio que dejó libre todo lo anterior.
    if ($esAdmin) {
        Write-Title 'Mantenimiento'
        if ($reparar) { Repair-Windows }
        else          { Write-Line 'Reparar Windows' 'omitido (respondiste N)' -tipo 'info' }
        Clear-WindowsTemp
        Clear-ErrorReport
        Clear-WindowsHistory
        Clear-WindowsCookie
        Clear-RecentFile
        Clear-ComponentStore
        Enable-Trim
        Optimize-Disk
    }

    # 4. Resumen de lo borrado, y revisión del equipo ya limpio.
    Write-Title 'Resumen'
    Show-Summary $libreAntes

    Write-Title 'Revisión del equipo'
    Show-Disk
    Show-DiskHealth
    Show-Trim
    Show-Battery
    Show-DaysSinceRestart
    Show-PendingRestart
    Show-StartupProgram

    Write-Title 'Listo'
}

# Sin try a propósito: si algo falla sale en rojo y el resto sigue, igual que antes. Stop-Log cierra el log.
Main
Stop-Log
