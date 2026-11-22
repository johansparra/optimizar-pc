<#PSScriptInfo
.VERSION 1.1.0
.GUID 4b276250-ee71-40e3-9732-65f50b5d5cb3
.AUTHOR johansparra
.PROJECTURI https://github.com/johansparra/optimizar-pc
.RELEASENOTES
1.1.0 (2026-11-22): deja un log en la carpeta log\ solo con lo importante: el inicio, cada limpieza (manual o automática) con lo que liberó, cuando se activa o desactiva la limpieza automática, los errores y el fin. Nunca anota cada lectura de la RAM.
#>

<#
.SYNOPSIS
Ícono junto al reloj con el % de RAM en uso.
.DESCRIPTION
Doble clic en Monitor-Memoria.bat. No necesita administrador. Doble clic en el ícono: liberar memoria. Clic derecho: menú (liberar, limpieza automática, Administrador de tareas, Salir). Deja un log de cada limpieza en la carpeta log\.
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
    Read-Host '   Presiona Enter para cerrar'   # esta ventana se cierra sola al terminar
    return
}

Add-Type -AssemblyName System.Windows.Forms, System.Drawing, Microsoft.VisualBasic

# ════════ CONFIGURACIÓN ════════

$SegundosEntreLecturas = 2
$PctNaranja       = 70       # desde aquí el ícono se pone naranja
$PctRojo          = 85       # desde aquí, rojo
$PctAuto          = 85       # la limpieza automática libera memoria al pasar de este %
$MinutosEntreAuto = 10       # y espera al menos esto antes de volver a hacerlo
$AutoAlIniciar    = $false   # $true para que la limpieza automática arranque activada
$NivelLog         = 'INFO'   # log en la carpeta log\: solo anota el inicio, cada limpieza y el fin (nunca cada lectura)
$PrefijoLog       = 'monitor-mem'   # nombre de los archivos de log

# Misma lista que Limpiar-Memoria. Solo se toca a estos programas. Nombres sin .exe.
$Programas = 'chrome', 'msedge', 'msedgewebview2', 'firefox', 'brave', 'opera',
    'OUTLOOK', 'olk', 'WINWORD', 'EXCEL', 'POWERPNT', 'ONENOTE', 'MSACCESS',
    'ms-teams', 'Teams', 'lync', 'CiscoCollabHost', 'atmgr', 'Zoom', 'slack',
    'explorer', 'SearchHost', 'StartMenuExperienceHost', 'ShellExperienceHost', 'TextInputHost', 'Widgets',
    'Acrobat', 'AcroRd32', 'Code', 'notepad', 'Spotify', 'WhatsApp', 'Discord'

# Objetos compartidos por todo el archivo (como los atributos de una clase en Java)
# ($script: delante de una variable = cambiar la compartida, no crear una nueva dentro del método)
$Info    = New-Object Microsoft.VisualBasic.Devices.ComputerInfo                     # lee la RAM
$Tray    = New-Object System.Windows.Forms.NotifyIcon                                # el ícono junto al reloj
$Reloj   = New-Object System.Windows.Forms.Timer                                     # actualiza el ícono cada X segundos
$Espera  = New-Object System.Windows.Forms.Timer                                     # mide el resultado 1,5 s después de liberar
$Candado = New-Object System.Threading.Mutex($false, 'Local\MonitorMemoriaRAM')      # para abrir una sola copia
$Sesion  = (Get-Process -Id $PID).SessionId                                          # tu sesión de Windows
$script:UltimaAuto   = [datetime]::MinValue
$script:LibreAntesMB = 0
$script:TituloAviso  = ''

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

# ════════ VISTA (todo lo visual está aquí: el ícono, su menú y el texto de esta ventana) ════════

# Cada resultado tiene un tipo; aquí se decide su color.
$Colores = @{ ok = 'Green'; aviso = 'Yellow'; mal = 'Red'; info = 'DarkGray'; normal = 'Gray' }
$Iconos  = @{}   # un dibujo por cada %, se hace una sola vez
# Tamaño del ícono según el zoom de pantalla: 16 px al 100 %, 24 px al 150 %...
$Dpi      = (Get-ItemProperty 'HKCU:\Control Panel\Desktop\WindowMetrics' -ErrorAction SilentlyContinue).AppliedDPI
$TamIcono = [int](16 * $(if ($Dpi) { $Dpi } else { 96 }) / 96)
$Fuente   = New-Object System.Drawing.Font('Segoe UI', [single]($TamIcono * 0.56), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)

# Título grande al abrir el script.
function Write-Header($texto) {
    $Host.UI.RawUI.WindowTitle = $texto
    $linea = '═' * 62
    Write-Host ''
    Write-Host "  $linea" -ForegroundColor DarkCyan
    Write-Host "   $texto" -ForegroundColor Cyan
    Write-Host "  $linea" -ForegroundColor DarkCyan
}

# Una línea del reporte: qué se hizo a la izquierda, resultado a la derecha con el color de su tipo.
# También va al log, con el nivel que corresponde a su tipo.
function Write-Line($nombre, $resultado, $tipo = 'normal') {
    Write-Host ('   {0,-32} ' -f $nombre) -NoNewline   # el espacio final separa aunque el nombre sea largo
    Write-Host $resultado -ForegroundColor $Colores[$tipo]
    Write-LogLine (Get-LogLevel $tipo) ((@("$nombre".Trim(), "$resultado") -ne '') -join ': ')
}

# Color del ícono según el % de RAM.
function Get-IconColor($pct) {
    if ($pct -ge $PctRojo) { 'Firebrick' } elseif ($pct -ge $PctNaranja) { 'DarkOrange' } else { 'SeaGreen' }
}

# Cuadrito de esquinas redondeadas con el número en blanco.
function Get-Icon($pct) {
    if (-not $Iconos[$pct]) {
        $t = $TamIcono
        $bmp = New-Object System.Drawing.Bitmap($t, $t)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.SmoothingMode = 'AntiAlias'
        $g.TextRenderingHint = 'AntiAliasGridFit'
        $d = [int]($t / 2)   # tamaño de las esquinas redondeadas
        $forma = New-Object System.Drawing.Drawing2D.GraphicsPath
        $forma.AddArc(0, 0, $d, $d, 180, 90)
        $forma.AddArc($t - $d - 1, 0, $d, $d, 270, 90)
        $forma.AddArc($t - $d - 1, $t - $d - 1, $d, $d, 0, 90)
        $forma.AddArc(0, $t - $d - 1, $d, $d, 90, 90)
        $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromName((Get-IconColor $pct)))), $forma)
        $centrado = New-Object System.Drawing.StringFormat
        $centrado.Alignment = $centrado.LineAlignment = 'Center'
        $g.DrawString([string][math]::Min($pct, 99), $Fuente, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF(0, 1, $t, $t)), $centrado)
        $Iconos[$pct] = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    }
    $Iconos[$pct]
}

# Menú del clic derecho.
function Initialize-Menu {
    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    $script:ItemEstado = $menu.Items.Add('RAM')
    $script:ItemEstado.Enabled = $false   # solo informa
    [void]$menu.Items.Add('-')
    $liberar = $menu.Items.Add('Liberar memoria ahora', $null, { Clear-Memory 'Memoria liberada' })
    $liberar.Font = New-Object System.Drawing.Font($liberar.Font, [System.Drawing.FontStyle]::Bold)
    $script:ItemAuto = $menu.Items.Add("Liberar sola al pasar de $PctAuto %")
    $script:ItemAuto.CheckOnClick = $true
    $script:ItemAuto.Checked = $AutoAlIniciar
    $script:ItemAuto.Add_CheckedChanged({ Write-LogLine INFO ('Limpieza automática ' + $(if ($ItemAuto.Checked) { 'activada' } else { 'desactivada' })) })
    [void]$menu.Items.Add('Abrir Administrador de tareas', $null, { Start-Process taskmgr.exe })
    [void]$menu.Items.Add('-')
    [void]$menu.Items.Add('Salir', $null, { Exit-Monitor })
    $Tray.ContextMenuStrip = $menu
}

# ════════ MÉTODOS REUTILIZABLES ════════

function Get-RamPercent {
    [int](100 - 100 * $Info.AvailablePhysicalMemory / $Info.TotalPhysicalMemory)
}

function Get-FreeRamMB {
    $Info.AvailablePhysicalMemory / 1MB
}

# Texto con el detalle, para el tooltip y el menú.
function Get-RamDetail {
    $total = $Info.TotalPhysicalMemory / 1GB
    $libre = $Info.AvailablePhysicalMemory / 1GB
    '{0:N1} de {1:N1} GB · libre {2:N1} GB' -f ($total - $libre), $total, $libre
}

# Volver a fijar su propio límite hace que Windows le recorte la RAM que no está usando.
# Solo los programas de la lista abiertos en tu sesión.
function Clear-ProgramsRam {
    Get-Process -Name $Programas -ErrorAction SilentlyContinue | Where-Object SessionId -eq $Sesion |
        ForEach-Object { try { $_.MaxWorkingSet = $_.MaxWorkingSet } catch { Write-Verbose "Se salta (sin permiso o ya cerrado): $_" } }
}

# $true si ya hay otro monitor abierto (los dos usan el mismo candado).
function Test-AlreadyRunning {
    try { -not $Candado.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $false }   # el anterior se cerró mal
}

# ════════ ACCIONES (lo que pasa con cada evento) ════════

# Cada X segundos
function Update-Icon {
    $pct = Get-RamPercent
    $Tray.Icon = Get-Icon $pct
    $Tray.Text = "RAM en uso: $pct %`n$(Get-RamDetail)"
    $ItemEstado.Text = "RAM $pct % · $(Get-RamDetail)"
}

# Cada X segundos: si la limpieza automática está activada y la RAM pasa de $PctAuto.
function Invoke-AutoCleanup {
    $minutos = ((Get-Date) - $script:UltimaAuto).TotalMinutes
    if ($ItemAuto.Checked -and (Get-RamPercent) -ge $PctAuto -and $minutos -ge $MinutosEntreAuto) {
        $script:UltimaAuto = Get-Date
        Clear-Memory 'Limpieza automática de memoria'
    }
}

# Doble clic, "Liberar memoria ahora" o la limpieza automática. El resultado lo mide Show-Result
# 1,5 s después, sin congelar el ícono mientras tanto.
function Clear-Memory($titulo) {
    $script:LibreAntesMB = Get-FreeRamMB
    $script:TituloAviso = $titulo
    Clear-ProgramsRam
    $Espera.Start()
}

# 1,5 s después de liberar
function Show-Result {
    $Espera.Stop()
    $liberado = [math]::Max(0, (Get-FreeRamMB) - $script:LibreAntesMB)
    $resultado = '{0:N0} MB liberados. RAM en uso: {1} %' -f $liberado, (Get-RamPercent)
    $Tray.ShowBalloonTip(4000, $script:TituloAviso, $resultado, 'Info')
    Write-LogLine INFO "$($script:TituloAviso): $resultado"
    Update-Icon
}

# Clic derecho > Salir
function Exit-Monitor {
    $Reloj.Stop()
    $Tray.Visible = $false
    [System.Windows.Forms.Application]::Exit()
}

# ════════ MAIN ════════

function Main {
    # 1. Primero: solo una copia abierta.
    if (Test-AlreadyRunning) {
        [void][System.Windows.Forms.MessageBox]::Show('El monitor de memoria ya está abierto: búscalo junto al reloj (o en la flecha ^).', 'Monitor de memoria')
        return
    }

    # 2. Conectar el ícono, el menú y los relojes con sus acciones.
    Initialize-Menu
    $Tray.Add_DoubleClick({ Clear-Memory 'Memoria liberada' })
    $Reloj.Interval = $SegundosEntreLecturas * 1000
    $Reloj.Add_Tick({ Update-Icon; Invoke-AutoCleanup })
    $Espera.Interval = 1500
    $Espera.Add_Tick({ Show-Result })

    # 3. Mostrar el ícono y arrancar el reloj.
    Update-Icon
    $Tray.Visible = $true
    $Reloj.Start()

    # 4. Explicar en esta ventana cómo se usa, y esperar hasta que elijan Salir.
    Write-Header 'MONITOR DE MEMORIA'
    Start-Log
    Write-LogLine INFO ('Limpieza automática al iniciar: ' + $(if ($ItemAuto.Checked) { 'activada' } else { 'desactivada' }))
    Write-Line 'Estado' 'activo: mira el ícono junto al reloj' -tipo 'ok'
    Write-Line 'Liberar memoria' 'doble clic en el ícono'
    Write-Line 'Más opciones' 'clic derecho en el ícono (limpieza automática, Salir...)'
    Write-Line 'Esta ventana' 'déjala minimizada; si la cierras, el monitor se cierra' -tipo 'info'
    [System.Windows.Forms.Application]::Run()
    $Candado.ReleaseMutex()
}

# Sin try a propósito: si algo falla sale en rojo y el resto sigue, igual que antes. Stop-Log cierra el log.
Main
Stop-Log
