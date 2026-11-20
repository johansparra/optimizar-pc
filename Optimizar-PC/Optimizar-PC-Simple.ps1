# Optimizar-PC-Simple.ps1 - Borra temporales y cachés de tu usuario, reporta qué borró y revisa el equipo.
# Doble clic: limpieza. Clic derecho > Ejecutar como administrador: limpieza + mantenimiento de Windows.
# Orden del archivo: CHEQUEO INICIAL > CONFIGURACIÓN > VISTA > MÉTODOS REUTILIZABLES > REVISIÓN > LIMPIEZA > MANTENIMIENTO (solo admin) > MAIN (al final, como en Java).

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

# Contadores del resumen final; los suma Borrar-Archivos.
# ($script: = variable compartida por todo el archivo, como un atributo de clase en Java)
$script:TotalArchivos = 0
$script:TotalBytes    = 0

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

# Borra los archivos y las subcarpetas vacías con más de $horas de antigüedad, y reporta cuántos borró,
# cuánto pesaban y cuántos estaban en uso. Los que están en uso se dejan.
function Borrar-Archivos($nombre, $rutas, $horas = 0) {
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
    Borrar-CarpetasVacias $viejos
    $script:TotalArchivos += $archivos
    $script:TotalBytes    += $bytes
    $texto = if ($archivos) { '{0} archivos, {1:N1} MB' -f $archivos, ($bytes / 1MB) } else { 'nada' }
    if ($enUso) { $texto += " · $enUso en uso (se dejan)" }
    Escribir-Linea $nombre $texto $(if ($archivos) { 'ok' } else { 'info' })
}

# Borra las carpetas de la lista que quedaron vacías, de la más profunda a la menos profunda.
# Nunca toca accesos directos de carpeta (junctions/enlaces), para no salirse de la carpeta que se limpia.
function Borrar-CarpetasVacias($items) {
    $items | Where-Object { $_.PSIsContainer -and -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) } |
        Sort-Object { $_.FullName.Length } -Descending |
        ForEach-Object { try { $_.Delete() } catch {} }   # Delete() sin $true falla solo si no está vacía
}

# Borra la caché de un programa solo si está instalado y cerrado.
function Borrar-CacheSiCerrado($nombre, $proceso, $rutas) {
    if (-not (Get-Item $rutas -Force -ErrorAction SilentlyContinue)) { Escribir-Linea $nombre 'no instalado' 'info'; return }
    if (Get-Process $proceso -ErrorAction SilentlyContinue) { Escribir-Linea $nombre 'se salta: el programa está abierto' 'aviso'; return }
    Borrar-Archivos $nombre $rutas
}

# Carpetas de caché de los navegadores hechos sobre Chrome (Chrome, Edge, Brave), en todos sus perfiles.
# No incluye contraseñas, historial, cookies ni sesiones.
function Obtener-CachesChromium($datosUsuario) {
    "$datosUsuario\*\Cache", "$datosUsuario\*\Code Cache", "$datosUsuario\*\GPUCache"
}

# Ejecuta una herramienta de Windows, espera a que termine y reporta si salió bien.
function Ejecutar-Herramienta($nombre, $programa, $argumentos) {
    Escribir-Linea $nombre 'ejecutando...' 'info'
    $proceso = Start-Process $programa $argumentos -Wait -PassThru -NoNewWindow
    if ($proceso.ExitCode -eq 0) { Escribir-Linea $nombre 'OK' 'ok' }
    else                         { Escribir-Linea $nombre "terminó con código $($proceso.ExitCode)" 'mal' }
}

function Obtener-EspacioLibreMB {
    (Get-PSDrive $Unidad).Free / 1MB
}

# $true si el script se abrió con "Ejecutar como administrador" (funciona con Windows en cualquier idioma).
function Es-Administrador {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# El Administrador de tareas guarda en "StartupApproved" lo que desactivas: primer byte impar = desactivado.
function Esta-Desactivado($claveAprobados, $nombre) {
    $valor = (Get-ItemProperty $claveAprobados -Name $nombre -ErrorAction SilentlyContinue).$nombre
    [bool]($valor -and ($valor[0] % 2 -eq 1))
}

# Programas habilitados de una clave "Run" del registro.
function Obtener-InicioRegistro($clave, $claveAprobados) {
    (Get-Item $clave -ErrorAction SilentlyContinue).Property |
        Where-Object { -not (Esta-Desactivado $claveAprobados $_) }
}

# Programas habilitados de una carpeta "Inicio" (accesos directos).
function Obtener-InicioCarpeta($carpeta, $claveAprobados) {
    Get-ChildItem $carpeta -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne 'desktop.ini' -and -not (Esta-Desactivado $claveAprobados $_.Name) } |
        ForEach-Object BaseName
}

# ════════ REVISIÓN (un método = un dato) ════════

function Mostrar-Disco {
    $disco = Get-PSDrive $Unidad
    $total = $disco.Used + $disco.Free
    Escribir-Barra "Disco $Unidad" (100 * $disco.Used / $total) ('{0:N1} GB libres de {1:N1} GB' -f ($disco.Free / 1GB), ($total / 1GB))
}

function Mostrar-Memoria {
    $os = Get-CimInstance Win32_OperatingSystem
    $usadaKB = $os.TotalVisibleMemorySize - $os.FreePhysicalMemory
    Escribir-Barra 'Memoria' (100 * $usadaKB / $os.TotalVisibleMemorySize) ('{0:N1} GB de {1:N1} GB en uso' -f ($usadaKB / 1MB), ($os.TotalVisibleMemorySize / 1MB))
}

function Mostrar-DiasSinReiniciar {
    $dias = ((Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime).Days
    if ($dias -ge 7) { Escribir-Linea 'Días sin reiniciar' "$dias (reinicia con Inicio > Reiniciar)" 'aviso' }
    else             { Escribir-Linea 'Días sin reiniciar' $dias 'ok' }
}

function Mostrar-ReinicioPendiente {
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        Escribir-Linea 'Actualizaciones' 'esperando un reinicio' 'aviso'
    } else {
        Escribir-Linea 'Actualizaciones' 'sin reinicio pendiente' 'ok'
    }
}

# Igual que Administrador de tareas > Aplicaciones de arranque, solo las habilitadas.
function Mostrar-ProgramasInicio {
    $aprobados = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
    $programas = @(
        Obtener-InicioRegistro 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'             "HKCU:\$aprobados\Run"
        Obtener-InicioRegistro 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'             "HKLM:\$aprobados\Run"
        Obtener-InicioRegistro 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' "HKLM:\$aprobados\Run32"
        Obtener-InicioCarpeta ([Environment]::GetFolderPath('Startup'))       "HKCU:\$aprobados\StartupFolder"
        Obtener-InicioCarpeta ([Environment]::GetFolderPath('CommonStartup')) "HKLM:\$aprobados\StartupFolder"
    ) | Sort-Object -Unique
    $tipo = if ($programas.Count -gt 8) { 'aviso' } else { 'ok' }
    Escribir-Linea 'Arrancan con Windows' ('{0} programas habilitados' -f $programas.Count) $tipo
    $programas | ForEach-Object { Escribir-Linea '' $_ }
}

# Lo que se borró en total (archivos contados) y lo que realmente ganó el disco (incluye Papelera y Liberador).
function Mostrar-Resumen($libreAntes) {
    Escribir-Linea 'Archivos borrados' ('{0} ({1:N1} MB)' -f $script:TotalArchivos, ($script:TotalBytes / 1MB)) 'ok'
    Escribir-Linea "Espacio ganado en $Unidad" ('{0:N0} MB' -f [math]::Max(0, (Obtener-EspacioLibreMB) - $libreAntes)) 'ok'
}

# ════════ LIMPIEZA (un método = una tarea) ════════

function Vaciar-Papelera {
    $elementos = (New-Object -ComObject Shell.Application).NameSpace(10).Items().Count
    if ($elementos -eq 0) { Escribir-Linea 'Papelera' 'ya estaba vacía' 'info'; return }
    if ((Read-Host "   La Papelera tiene $elementos elementos. ¿Vaciarla? (S/N)") -match '^\s*s') {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        Escribir-Linea 'Papelera' "$elementos elementos vaciados" 'ok'
    } else {
        Escribir-Linea 'Papelera' 'no se vació (respondiste N)' 'info'
    }
}

function Limpiar-Temp {
    Borrar-Archivos 'Temporales (%TEMP%)' $env:TEMP $HorasMinimas
}

function Limpiar-CacheInternet {
    Borrar-Archivos 'Caché de internet (Windows)' "$Local\Microsoft\Windows\INetCache" $HorasMinimas
}

function Limpiar-Chrome {
    Borrar-CacheSiCerrado 'Caché de Chrome' 'chrome' (Obtener-CachesChromium "$Local\Google\Chrome\User Data")
}

function Limpiar-Edge {
    Borrar-CacheSiCerrado 'Caché de Edge' 'msedge' (Obtener-CachesChromium "$Local\Microsoft\Edge\User Data")
}

function Limpiar-Brave {
    Borrar-CacheSiCerrado 'Caché de Brave' 'brave' (Obtener-CachesChromium "$Local\BraveSoftware\Brave-Browser\User Data")
}

function Limpiar-Firefox {
    Borrar-CacheSiCerrado 'Caché de Firefox' 'firefox' "$Local\Mozilla\Firefox\Profiles\*\cache2"
}

function Limpiar-Teams {
    Borrar-CacheSiCerrado 'Caché de Teams' 'ms-teams' "$Local\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams"
}

# Miniaturas e íconos del Explorador; Windows los vuelve a crear.
function Limpiar-Miniaturas {
    Borrar-Archivos 'Miniaturas del Explorador' "$Local\Microsoft\Windows\Explorer\*.db"
}

# Liberador de espacio de Windows con las opciones guardadas antes con "cleanmgr /sageset:1".
# No pide admin: sin admin limpia solo lo que tu usuario puede borrar. Si nunca se configuró, no hace nada.
function Ejecutar-LiberadorEspacio {
    Ejecutar-Herramienta 'Liberador de espacio' 'cleanmgr.exe' '/sagerun:1'
}

# ════════ MANTENIMIENTO (solo administrador: Main los salta si no lo eres) ════════

# Temporales de Windows (C:\Windows\Temp). Sin admin Windows ni siquiera deja ver la carpeta.
function Limpiar-TempWindows {
    Borrar-Archivos 'Temporales de Windows' "$env:WINDIR\Temp" $HorasMinimas
}

# --- Solo para tu PC personal ---------------------------------------------------------------
# Estos borran rastros de uso (informes de errores, historial, cookies, recientes). En un PC de
# empresa el antivirus lo puede ver como "borrado de evidencia"; por eso solo corren como admin,
# y en la laptop del banco no tienes admin.

# Volcados de programas que se cerraron con error, e informes pendientes de enviar a Microsoft.
function Limpiar-ReportesErrores {
    Borrar-Archivos 'Informes de errores' "$Local\CrashDumps", "$Local\Microsoft\Windows\WER\ReportQueue"
}

# Historial del antiguo Internet Explorer / Explorador de Windows.
function Limpiar-Historial {
    Borrar-Archivos 'Historial de Windows' "$Local\Microsoft\Windows\History"
}

# Cookies del antiguo Internet Explorer (en Windows 11 casi siempre está vacía).
function Limpiar-Cookies {
    Borrar-Archivos 'Cookies de Windows' "$env:APPDATA\Microsoft\Windows\Cookies"
}

# Archivos recientes del Explorador. También borra lo anclado en las listas de la barra de tareas.
function Limpiar-Recientes {
    Borrar-Archivos 'Archivos recientes' "$env:APPDATA\Microsoft\Windows\Recent"
}
# ----------------------------------------------------------------------------------------------

# DISM: borra versiones viejas de actualizaciones de Windows (carpeta WinSxS). Tarda varios minutos.
function Limpiar-ComponentesWindows {
    Ejecutar-Herramienta 'DISM (WinSxS)' 'Dism.exe' '/Online /Cleanup-Image /StartComponentCleanup'
}

# TRIM: deja que el disco SSD sepa qué espacio quedó libre. En Windows 11 ya viene activado.
function Activar-Trim {
    Ejecutar-Herramienta 'Activar TRIM' 'fsutil.exe' 'behavior set DisableDeleteNotify 0'
}

# Desfragmenta los discos normales y hace TRIM en los SSD (todos los discos del equipo).
function Optimizar-Discos {
    Ejecutar-Herramienta 'Optimizar discos' 'defrag.exe' '/C /O'
}

# ════════ MAIN ════════

function Main {
    Escribir-Encabezado 'OPTIMIZAR PC'

    # 1. Primero: ¿con qué permisos corre? Eso decide qué se puede hacer.
    $esAdmin = Es-Administrador
    if ($esAdmin) { Escribir-Linea 'Modo' 'administrador: limpieza + mantenimiento' 'ok' }
    else          { Escribir-Linea 'Modo' 'normal: solo limpieza (el mantenimiento pide admin)' 'info' }
    $libreAntes = Obtener-EspacioLibreMB

    # 2. Limpieza. La Papelera va primero porque es lo único que pregunta; el resto corre sin interrupciones.
    Escribir-Titulo 'Limpieza'
    Vaciar-Papelera
    Limpiar-Temp
    Limpiar-CacheInternet
    Limpiar-Chrome
    Limpiar-Edge
    Limpiar-Brave
    Limpiar-Firefox
    Limpiar-Teams
    Limpiar-Miniaturas
    Ejecutar-LiberadorEspacio

    # 3. Mantenimiento: después de borrar, para que DISM y la optimización trabajen sobre el disco ya limpio.
    #    Optimizar-Discos va último porque reorganiza el espacio que dejó libre todo lo anterior.
    if ($esAdmin) {
        Escribir-Titulo 'Mantenimiento'
        Limpiar-TempWindows
        Limpiar-ReportesErrores
        Limpiar-Historial
        Limpiar-Cookies
        Limpiar-Recientes
        Limpiar-ComponentesWindows
        Activar-Trim
        Optimizar-Discos
    }

    # 4. Resumen de lo borrado, y revisión del equipo ya limpio.
    Escribir-Titulo 'Resumen'
    Mostrar-Resumen $libreAntes

    Escribir-Titulo 'Revisión del equipo'
    Mostrar-Disco
    Mostrar-Memoria
    Mostrar-DiasSinReiniciar
    Mostrar-ReinicioPendiente
    Mostrar-ProgramasInicio

    Escribir-Titulo 'Listo'
}

Main
