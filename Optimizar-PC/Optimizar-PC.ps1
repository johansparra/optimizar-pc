<#PSScriptInfo
.VERSION 1.2.0
.GUID 81b2e606-23df-4e75-8725-5df78a0609fc
.AUTHOR johansparra
.PROJECTURI https://github.com/johansparra/optimizar-pc
.RELEASENOTES
1.2.0 (2026-11-20): la revisión del equipo ahora muestra la salud de los discos (SMART) y, en laptops, de la batería; como administrador ofrece reparar Windows (DISM y sfc) con S/N. El Liberador de espacio ya no deja el script colgado (se espera con un tope de tiempo) y muestra cuánto tardó y cuánto liberó.
#>

<#
.SYNOPSIS
Borra temporales y cachés de tu usuario, reporta qué borró y revisa el equipo (espacio, salud de discos y batería).
.DESCRIPTION
Doble clic en Optimizar-PC.bat: limpieza. Clic derecho > Ejecutar como administrador: limpieza + mantenimiento de Windows.
.NOTES
Orden del archivo: CHEQUEO INICIAL > CONFIGURACIÓN > VISTA > MÉTODOS REUTILIZABLES > REVISIÓN > LIMPIEZA > MANTENIMIENTO (solo admin) > MAIN (al final, como en Java).
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

# Contadores del resumen final; los suma Remove-OldFile.
# ($script: = variable compartida por todo el archivo, como un atributo de clase en Java)
$script:TotalArchivos = 0
$script:TotalBytes    = 0

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

# Borra los archivos y las subcarpetas vacías con más de $horas de antigüedad, y reporta cuántos borró,
# cuánto pesaban y cuántos estaban en uso. Los que están en uso se dejan.
function Remove-OldFile($nombre, $rutas, $horas = 0) {
    $limite = (Get-Date).AddHours(-$horas)
    # La lista se toma antes de borrar: al borrar un archivo, su carpeta queda con fecha de ahora.
    $viejos = @(Get-Item $rutas -Force -ErrorAction SilentlyContinue |
        Get-ChildItem -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object LastWriteTime -lt $limite)
    $archivos = 0
    $bytes = 0
    $enUso = 0
    foreach ($archivo in ($viejos | Where-Object { -not $_.PSIsContainer })) {
        try {
            Remove-Item -LiteralPath $archivo.FullName -Force -ErrorAction Stop
            $archivos++
            $bytes += $archivo.Length
        } catch { $enUso++ }
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
        ForEach-Object { try { $_.Delete() } catch { Write-Verbose "Se deja: $_" } }   # Delete() sin $true falla solo si no está vacía
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
    if ((Read-Host "   La Papelera tiene $elementos elementos. ¿Vaciarla? (S/N)") -match '^\s*s') {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        Write-Line 'Papelera' "$elementos elementos vaciados" -tipo 'ok'
    } else {
        Write-Line 'Papelera' 'no se vació (respondiste N)' -tipo 'info'
    }
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

# Liberador de espacio de Windows con las opciones guardadas antes con "cleanmgr /sageset:1".
# No pide admin: sin admin limpia solo lo que tu usuario puede borrar. Si nunca se configuró, no hace nada.
# cleanmgr abre procesos aparte y su ventana se cierra antes de terminar; con Start-Process -Wait el
# script se quedaba colgado. Se lanza y se espera a que no quede ningún cleanmgr, con un tope de 3 min
# para no bloquear nunca: si tarda más, sigue solo en segundo plano y el script continúa.
function Invoke-DiskCleanup {
    Write-Line 'Liberador de espacio' 'ejecutando...' -tipo 'info'
    $libreAntes = Get-FreeSpaceMB
    $reloj = [Diagnostics.Stopwatch]::StartNew()
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
# ese almacén sano para reponer los archivos del sistema. Tarda varios minutos; por eso pregunta antes.
function Repair-Windows {
    if ((Read-Host '   ¿Reparar archivos de Windows? Tarda varios minutos (S/N)') -notmatch '^\s*s') {
        Write-Line 'Reparar Windows' 'omitido (respondiste N)' -tipo 'info'; return
    }
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

    # 1. Primero: ¿con qué permisos corre? Eso decide qué se puede hacer.
    $esAdmin = Test-Admin
    if ($esAdmin) { Write-Line 'Modo' 'administrador: limpieza + mantenimiento' -tipo 'ok' }
    else          { Write-Line 'Modo' 'normal: solo limpieza (el mantenimiento pide admin)' -tipo 'info' }
    $libreAntes = Get-FreeSpaceMB

    # 2. Limpieza. La Papelera va primero porque es lo único que pregunta; el resto corre sin interrupciones.
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
    Invoke-DiskCleanup

    # 3. Mantenimiento: primero reparar Windows (DISM y sfc necesitan un almacén de componentes completo,
    #    antes de que Clear-ComponentStore lo recorte), luego borrar, y al final optimizar el disco ya limpio.
    #    Optimize-Disk va último porque reorganiza el espacio que dejó libre todo lo anterior.
    if ($esAdmin) {
        Write-Title 'Mantenimiento'
        Repair-Windows
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

Main
