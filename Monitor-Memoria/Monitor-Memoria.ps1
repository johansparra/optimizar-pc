<#PSScriptInfo
.VERSION 1.0.2
.GUID 4b276250-ee71-40e3-9732-65f50b5d5cb3
.AUTHOR johansparra
.PROJECTURI https://github.com/johansparra/optimizar-pc
.RELEASENOTES
1.0.2 (2026-11-19): sin avisos de PSScriptAnalyzer (argumentos con nombre, el catch vacío ahora deja nota, Write-Host y -WhatIf marcados como intencionales). El script hace lo mismo.
1.0.1 (2026-11-19): enlace del proyecto actualizado al nuevo nombre del repositorio en GitHub (optimizar-pc).
1.0.0 (2026-11-19): primera versión con este bloque. Estructura por métodos, VISTA, chequeo de PowerShell restringido y bloque de administrador.
#>

<#
.SYNOPSIS
Ícono junto al reloj con el % de RAM en uso.
.DESCRIPTION
Doble clic en Monitor-Memoria.bat. No necesita administrador. Doble clic en el ícono: liberar memoria. Clic derecho: menú (liberar, limpieza automática, Administrador de tareas, Salir).
.NOTES
Orden del archivo: CHEQUEO INICIAL > CONFIGURACIÓN > VISTA > MÉTODOS REUTILIZABLES > ACCIONES > MAIN (al final, como en Java).
Versión y notas de versión: bloque PSScriptInfo de arriba (se mantiene con la skill actualizar-version-scripts).
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
function Write-Line($nombre, $resultado, $tipo = 'normal') {
    Write-Host ('   {0,-32} ' -f $nombre) -NoNewline   # el espacio final separa aunque el nombre sea largo
    Write-Host $resultado -ForegroundColor $Colores[$tipo]
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
    $Tray.ShowBalloonTip(4000, $script:TituloAviso, ('{0:N0} MB liberados. RAM en uso: {1} %' -f $liberado, (Get-RamPercent)), 'Info')
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
    Write-Line 'Estado' 'activo: mira el ícono junto al reloj' -tipo 'ok'
    Write-Line 'Liberar memoria' 'doble clic en el ícono'
    Write-Line 'Más opciones' 'clic derecho en el ícono (limpieza automática, Salir...)'
    Write-Line 'Esta ventana' 'déjala minimizada; si la cierras, el monitor se cierra' -tipo 'info'
    [System.Windows.Forms.Application]::Run()
    $Candado.ReleaseMutex()
}

Main
