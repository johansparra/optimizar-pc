<#
    Optimizar-PC.ps1  -  Limpia archivos temporales y cachés, y revisa el equipo.
    NO necesita permisos de administrador: solo toca archivos de TU usuario.

    Qué limpia
      - Archivos temporales con más de 24 horas (los recientes se dejan para no
        afectar programas abiertos; los que están en uso se saltan solos)
      - Caché de Internet de Windows
      - Caché de Chrome, Edge, Brave y Firefox, solo si el navegador está cerrado
        (no toca contraseñas, historial, cookies ni sesiones abiertas)
      - La Papelera de reciclaje, solo si dices que sí
    Qué revisa
      - Espacio en disco, días sin reiniciar, actualizaciones pendientes,
        programas que arrancan con Windows y los que más memoria usan

    Uso
      Doble clic en Optimizar-PC.bat
      Modo prueba (calcula pero no borra nada), desde PowerShell:
        powershell -ExecutionPolicy RemoteSigned -File .\Optimizar-PC.ps1 -Simular
#>
param([switch]$Simular)

$HorasMinimas = 24   # antigüedad mínima de un archivo temporal para borrarlo

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

function Write-Seccion([string]$Texto) {
    Write-Host ''
    Write-Host "   $Texto" -ForegroundColor Cyan
    Write-Host ('   ' + '─' * 58) -ForegroundColor DarkGray
}

function Write-Barra([string]$Etiqueta, [double]$Pct, [string]$Detalle) {
    $ancho = 30
    $llenos = [int][math]::Round([math]::Min(100, [math]::Max(0, $Pct)) / 100 * $ancho)
    $color = if ($Pct -ge 90) { 'Red' } elseif ($Pct -ge 80) { 'Yellow' } else { 'Green' }
    Write-Host ('   {0,-9}' -f $Etiqueta) -NoNewline
    Write-Host ('█' * $llenos) -ForegroundColor $color -NoNewline
    Write-Host ('░' * ($ancho - $llenos)) -ForegroundColor DarkGray -NoNewline
    Write-Host (' {0,3:N0} %   {1}' -f $Pct, $Detalle)
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

function Get-ContenidoSinEnlaces([string]$Carpeta) {
    # Recorre la carpeta sin seguir accesos directos de carpeta (junctions /
    # enlaces simbólicos), para no salirse nunca de ella.
    foreach ($item in Get-ChildItem -LiteralPath $Carpeta -Force -ErrorAction SilentlyContinue) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
        $item
        if ($item.PSIsContainer) { Get-ContenidoSinEnlaces $item.FullName }
    }
}

function Clear-Carpeta([string]$Carpeta, [int]$Horas) {
    # Borra el contenido (no la carpeta) con más de $Horas de antigüedad.
    $limite = (Get-Date).AddHours(-$Horas)
    $items = @(Get-ContenidoSinEnlaces $Carpeta)
    $liberado = 0L
    $enUso = 0
    foreach ($archivo in $items) {
        if ($archivo.PSIsContainer -or $archivo.LastWriteTime -gt $limite) { continue }
        if ($Simular) { $liberado += $archivo.Length; continue }
        try {
            if ($archivo.IsReadOnly) { $archivo.IsReadOnly = $false }
            $archivo.Delete()
            $liberado += $archivo.Length
        } catch {
            $enUso++    # abierto por algún programa: se deja
        }
    }
    if (-not $Simular) {
        # Subcarpetas que quedaron vacías, de la más profunda a la menos profunda
        $carpetas = $items | Where-Object { $_.PSIsContainer -and $_.LastWriteTime -le $limite } |
            Sort-Object { $_.FullName.Length } -Descending
        foreach ($sub in $carpetas) {
            try { [IO.Directory]::Delete($sub.FullName, $false) } catch { }   # falla sola si no está vacía
        }
    }
    [pscustomobject]@{ Liberado = $liberado; EnUso = $enUso }
}

function Get-Papelera {
    # Tamaño de TU papelera en cada disco local
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $bytes = 0L
    $elementos = 0
    $unidades = @()
    foreach ($disco in Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3') {
        $ruta = "$($disco.DeviceID)\`$Recycle.Bin\$sid"
        if (-not (Test-Path -LiteralPath $ruta)) { continue }
        $archivos = @(Get-ContenidoSinEnlaces $ruta | Where-Object { -not $_.PSIsContainer })
        if (-not $archivos) { continue }
        $bytes += ($archivos | Measure-Object Length -Sum).Sum
        $elementos += @($archivos | Where-Object { $_.Name -like '$I*' }).Count
        $unidades += $disco.DeviceID.TrimEnd(':')
    }
    [pscustomobject]@{ Bytes = $bytes; Elementos = $elementos; Unidades = $unidades }
}

function Test-Desactivado([string]$Clave, [string]$Nombre) {
    # Aquí guarda Windows lo que desactivas en Administrador de tareas > Inicio
    # (si el primer byte es impar, está desactivado).
    $valor = (Get-ItemProperty -LiteralPath $Clave -Name $Nombre -ErrorAction SilentlyContinue).$Nombre
    return [bool]($valor -is [byte[]] -and $valor.Length -gt 0 -and ($valor[0] -band 1))
}

function Get-ProgramasInicio {
    $aprobados = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
    $claves = @(
        @{ Ruta = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run';             Aprobado = "HKCU:\$aprobados\Run" }
        @{ Ruta = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run';             Aprobado = "HKLM:\$aprobados\Run" }
        @{ Ruta = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Aprobado = "HKLM:\$aprobados\Run32" }
    )
    foreach ($clave in $claves) {
        $item = Get-Item -LiteralPath $clave.Ruta -ErrorAction SilentlyContinue
        if (-not $item) { continue }
        foreach ($nombre in $item.Property) {
            if ($nombre -and $nombre -ne '(default)' -and -not (Test-Desactivado $clave.Aprobado $nombre)) { $nombre }
        }
    }
    $carpetas = @(
        @{ Ruta = [Environment]::GetFolderPath('Startup');       Aprobado = "HKCU:\$aprobados\StartupFolder" }
        @{ Ruta = [Environment]::GetFolderPath('CommonStartup'); Aprobado = "HKLM:\$aprobados\StartupFolder" }
    )
    foreach ($carpeta in $carpetas) {
        if (-not $carpeta.Ruta) { continue }
        foreach ($acceso in Get-ChildItem -LiteralPath $carpeta.Ruta -File -ErrorAction SilentlyContinue) {
            if (-not (Test-Desactivado $carpeta.Aprobado $acceso.Name)) { $acceso.BaseName }
        }
    }
}

# ─── Programa ────────────────────────────────────────────────────────────────

if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Write-Host ''
    Write-Host '  PowerShell está restringido en este equipo por política de la empresa.' -ForegroundColor Red
    Write-Host '  Esta herramienta no se ejecuta aquí.' -ForegroundColor Red
    return
}

$Host.UI.RawUI.WindowTitle = 'Optimizar PC'
Write-Titulo 'OPTIMIZAR PC'
if ($Simular) { Write-Host '   MODO PRUEBA: solo calcula, no borra nada.' -ForegroundColor Yellow }

$local  = $env:LOCALAPPDATA
$chrome = "$local\Google\Chrome\User Data"
$edge   = "$local\Microsoft\Edge\User Data"
$brave  = "$local\BraveSoftware\Brave-Browser\User Data"
$limpiezas = @(
    @{ Nombre = 'Archivos temporales';         Horas = $HorasMinimas; Navegador = '';        Rutas = @($env:TEMP) }
    @{ Nombre = 'Caché de Internet (Windows)'; Horas = $HorasMinimas; Navegador = '';        Rutas = @("$local\Microsoft\Windows\INetCache") }
    @{ Nombre = 'Caché de Chrome';             Horas = 0;             Navegador = 'chrome';  Rutas = @("$chrome\*\Cache", "$chrome\*\Code Cache", "$chrome\*\GPUCache") }
    @{ Nombre = 'Caché de Edge';               Horas = 0;             Navegador = 'msedge';  Rutas = @("$edge\*\Cache", "$edge\*\Code Cache", "$edge\*\GPUCache") }
    @{ Nombre = 'Caché de Brave';              Horas = 0;             Navegador = 'brave';   Rutas = @("$brave\*\Cache", "$brave\*\Code Cache", "$brave\*\GPUCache") }
    @{ Nombre = 'Caché de Firefox';            Horas = 0;             Navegador = 'firefox'; Rutas = @("$local\Mozilla\Firefox\Profiles\*\cache2") }
)
$nombreNavegador = @{ chrome = 'Chrome'; msedge = 'Edge'; brave = 'Brave'; firefox = 'Firefox' }

# La Papelera se pregunta al principio, para que el resto corra sin interrupciones
$papelera = Get-Papelera
$vaciarPapelera = $false
if ($papelera.Bytes -gt 0 -and -not $Simular) {
    $pregunta = '   La Papelera tiene {0} ({1} elementos). ¿Vaciarla también? (S/N)' -f (Format-Tamano $papelera.Bytes), $papelera.Elementos
    $vaciarPapelera = (Read-Host $pregunta) -match '^\s*s'
}

Write-Seccion 'Limpieza'
$totalLiberado = 0L
foreach ($tarea in $limpiezas) {
    $carpetas = @(foreach ($ruta in $tarea.Rutas) {
        Get-Item -Path $ruta -Force -ErrorAction SilentlyContinue | Where-Object PSIsContainer
    })
    if (-not $carpetas) { continue }    # programa no instalado

    Write-Host ('   {0,-34}' -f $tarea.Nombre) -NoNewline
    if ($tarea.Navegador -and (Get-Process -Name $tarea.Navegador -ErrorAction SilentlyContinue)) {
        Write-Host ('{0,10}' -f 'omitido') -ForegroundColor Yellow -NoNewline
        Write-Host ('  ({0} está abierto)' -f $nombreNavegador[$tarea.Navegador]) -ForegroundColor DarkGray
        continue
    }
    $liberado = 0L
    $enUso = 0
    foreach ($carpeta in $carpetas) {
        $resultado = Clear-Carpeta $carpeta.FullName $tarea.Horas
        $liberado += $resultado.Liberado
        $enUso += $resultado.EnUso
    }
    $totalLiberado += $liberado
    if ($liberado -eq 0 -and $enUso -eq 0) { Write-Host ('{0,10}' -f 'nada') -ForegroundColor DarkGray; continue }
    Write-Host ('{0,10}' -f (Format-Tamano $liberado)) -ForegroundColor Green -NoNewline
    if ($enUso) { Write-Host ('  ({0} en uso, se dejan)' -f $enUso) -ForegroundColor DarkGray } else { Write-Host '' }
}

if ($papelera.Bytes -gt 0) {
    Write-Host ('   {0,-34}' -f 'Papelera de reciclaje') -NoNewline
    if ($Simular) {
        Write-Host ('{0,10}' -f (Format-Tamano $papelera.Bytes)) -ForegroundColor Green -NoNewline
        Write-Host '  (solo si confirmas)' -ForegroundColor DarkGray
    } elseif ($vaciarPapelera) {
        foreach ($unidad in $papelera.Unidades) { Clear-RecycleBin -DriveLetter $unidad -Force -ErrorAction SilentlyContinue }
        $restante = (Get-Papelera).Bytes
        $totalLiberado += $papelera.Bytes - $restante
        Write-Host ('{0,10}' -f (Format-Tamano ($papelera.Bytes - $restante))) -ForegroundColor Green
    } else {
        Write-Host ('{0,10}' -f 'no') -ForegroundColor DarkGray -NoNewline
        Write-Host ('  (quedan {0})' -f (Format-Tamano $papelera.Bytes)) -ForegroundColor DarkGray
    }
}

Write-Host ('   ' + '─' * 58) -ForegroundColor DarkGray
$etiquetaTotal = if ($Simular) { 'Se liberaría' } else { 'Total liberado' }
Write-Host ('   {0,-34}' -f $etiquetaTotal) -NoNewline
Write-Host ('{0,10}' -f (Format-Tamano $totalLiberado)) -ForegroundColor Green

# ─── Revisión del equipo ─────────────────────────────────────────────────────

Write-Seccion 'Revisión del equipo'

$disco = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
$pctDisco = 100 * ($disco.Size - $disco.FreeSpace) / $disco.Size
Write-Barra "Disco $env:SystemDrive" $pctDisco ('{0} libres de {1}' -f (Format-Tamano $disco.FreeSpace), (Format-Tamano $disco.Size))

$os = Get-CimInstance Win32_OperatingSystem
$pctRam = 100 * ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize
Write-Barra 'Memoria' $pctRam ('{0} de {1} en uso' -f (Format-Tamano (($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) * 1KB)), (Format-Tamano ($os.TotalVisibleMemorySize * 1KB)))
Write-Host ''

if ($pctDisco -ge 90) { Write-Estado mal 'El disco está casi lleno: mueve o borra archivos grandes (Descargas, videos).' }
elseif ($pctDisco -ge 80) { Write-Estado aviso 'Queda poco espacio en el disco.' }

$encendido = (Get-Date) - $os.LastBootUpTime
$dias = [int][math]::Floor($encendido.TotalDays)
if ($dias -ge 7) {
    Write-Estado aviso "Lleva $dias días sin reiniciar. Usa Inicio > Reiniciar"
    Write-Host '        ("Apagar" no limpia igual, por el inicio rápido de Windows).' -ForegroundColor DarkGray
} elseif ($dias -ge 1) {
    Write-Estado ok ("Reiniciado hace $dias " + $(if ($dias -eq 1) { 'día' } else { 'días' }))
} else {
    Write-Estado ok ('Reiniciado hace {0} horas' -f [int][math]::Floor($encendido.TotalHours))
}

if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
    Write-Estado aviso 'Windows tiene actualizaciones esperando un reinicio.'
} else {
    Write-Estado ok 'Sin actualizaciones pendientes de reinicio'
}

$inicio = @(Get-ProgramasInicio | Sort-Object -Unique)
if ($inicio.Count -eq 0) {
    Write-Estado ok 'Ningún programa extra arranca con Windows'
} else {
    $lista = ($inicio | Select-Object -First 6) -join ', '
    if ($inicio.Count -gt 6) { $lista += " y $($inicio.Count - 6) más" }
    $tipo = if ($inicio.Count -gt 8) { 'aviso' } else { 'ok' }
    Write-Estado $tipo "$($inicio.Count) programas arrancan con Windows: $lista"
    if ($tipo -eq 'aviso') {
        Write-Host '        Desactiva los que no uses: Administrador de tareas > Aplicaciones de arranque.' -ForegroundColor DarkGray
    }
}

$sistema = 'Idle', 'System', 'Secure System', 'Registry', 'Memory Compression'
$top = Get-Process | Where-Object { $sistema -notcontains $_.ProcessName } | Group-Object ProcessName | ForEach-Object {
    [pscustomobject]@{ Nombre = $_.Name; Cantidad = $_.Count; Bytes = ($_.Group | Measure-Object WorkingSet64 -Sum).Sum }
} | Sort-Object Bytes -Descending | Select-Object -First 5
Write-Host ''
Write-Host '   Lo que más memoria usa ahora:' -ForegroundColor Gray
foreach ($programa in $top) {
    $nombre = if ($programa.Cantidad -gt 1) { '{0} ({1})' -f $programa.Nombre, $programa.Cantidad } else { $programa.Nombre }
    Write-Host ('      {0,-32}{1,10}' -f $nombre, (Format-Tamano $programa.Bytes))
}

Write-Host ''
Write-Host '   Listo.' -ForegroundColor Green
