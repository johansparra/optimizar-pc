# Monitor-Memoria.ps1 - Ícono junto al reloj con el % de RAM en uso. Sin administrador.
# Doble clic en el ícono: liberar memoria. Clic derecho: menú (liberar, limpieza automática, Administrador de tareas, Salir).
# Orden del archivo: CHEQUEO INICIAL > CONFIGURACIÓN > VISTA > MÉTODOS REUTILIZABLES > ACCIONES > MAIN (al final, como en Java).

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
function Escribir-Encabezado($texto) {
    $Host.UI.RawUI.WindowTitle = $texto
    $linea = '═' * 62
    Write-Host ''
    Write-Host "  $linea" -ForegroundColor DarkCyan
    Write-Host "   $texto" -ForegroundColor Cyan
    Write-Host "  $linea" -ForegroundColor DarkCyan
}

# Una línea del reporte: qué se hizo a la izquierda, resultado a la derecha con el color de su tipo.
function Escribir-Linea($nombre, $resultado, $tipo = 'normal') {
    Write-Host ('   {0,-32} ' -f $nombre) -NoNewline   # el espacio final separa aunque el nombre sea largo
    Write-Host $resultado -ForegroundColor $Colores[$tipo]
}

# Color del ícono según el % de RAM.
function Obtener-ColorIcono($pct) {
    if ($pct -ge $PctRojo) { 'Firebrick' } elseif ($pct -ge $PctNaranja) { 'DarkOrange' } else { 'SeaGreen' }
}

# Cuadrito de esquinas redondeadas con el número en blanco.
function Dibujar-Icono($pct) {
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
        $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromName((Obtener-ColorIcono $pct)))), $forma)
        $centrado = New-Object System.Drawing.StringFormat
        $centrado.Alignment = $centrado.LineAlignment = 'Center'
        $g.DrawString([string][math]::Min($pct, 99), $Fuente, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF(0, 1, $t, $t)), $centrado)
        $Iconos[$pct] = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    }
    $Iconos[$pct]
}

# Menú del clic derecho.
function Crear-Menu {
    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    $script:ItemEstado = $menu.Items.Add('RAM')
    $script:ItemEstado.Enabled = $false   # solo informa
    [void]$menu.Items.Add('-')
    $liberar = $menu.Items.Add('Liberar memoria ahora', $null, { Liberar-Memoria 'Memoria liberada' })
    $liberar.Font = New-Object System.Drawing.Font($liberar.Font, [System.Drawing.FontStyle]::Bold)
    $script:ItemAuto = $menu.Items.Add("Liberar sola al pasar de $PctAuto %")
    $script:ItemAuto.CheckOnClick = $true
    $script:ItemAuto.Checked = $AutoAlIniciar
    [void]$menu.Items.Add('Abrir Administrador de tareas', $null, { Start-Process taskmgr.exe })
    [void]$menu.Items.Add('-')
    [void]$menu.Items.Add('Salir', $null, { Salir })
    $Tray.ContextMenuStrip = $menu
}

# ════════ MÉTODOS REUTILIZABLES ════════

function Obtener-PorcentajeRam {
    [int](100 - 100 * $Info.AvailablePhysicalMemory / $Info.TotalPhysicalMemory)
}

function Obtener-RamLibreMB {
    $Info.AvailablePhysicalMemory / 1MB
}

# Texto con el detalle, para el tooltip y el menú.
function Obtener-DetalleRam {
    $total = $Info.TotalPhysicalMemory / 1GB
    $libre = $Info.AvailablePhysicalMemory / 1GB
    '{0:N1} de {1:N1} GB · libre {2:N1} GB' -f ($total - $libre), $total, $libre
}

# Volver a fijar su propio límite hace que Windows le recorte la RAM que no está usando.
# Solo los programas de la lista abiertos en tu sesión.
function Liberar-RamProgramas {
    Get-Process -Name $Programas -ErrorAction SilentlyContinue | Where-Object SessionId -eq $Sesion |
        ForEach-Object { try { $_.MaxWorkingSet = $_.MaxWorkingSet } catch {} }
}

# $true si ya hay otro monitor abierto (los dos usan el mismo candado).
function Ya-EstaAbierto {
    try { -not $Candado.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $false }   # el anterior se cerró mal
}

# ════════ ACCIONES (lo que pasa con cada evento) ════════

# Cada X segundos
function Actualizar-Icono {
    $pct = Obtener-PorcentajeRam
    $Tray.Icon = Dibujar-Icono $pct
    $Tray.Text = "RAM en uso: $pct %`n$(Obtener-DetalleRam)"
    $ItemEstado.Text = "RAM $pct % · $(Obtener-DetalleRam)"
}

# Cada X segundos: si la limpieza automática está activada y la RAM pasa de $PctAuto.
function Revisar-LimpiezaAutomatica {
    $minutos = ((Get-Date) - $script:UltimaAuto).TotalMinutes
    if ($ItemAuto.Checked -and (Obtener-PorcentajeRam) -ge $PctAuto -and $minutos -ge $MinutosEntreAuto) {
        $script:UltimaAuto = Get-Date
        Liberar-Memoria 'Limpieza automática de memoria'
    }
}

# Doble clic, "Liberar memoria ahora" o la limpieza automática. El resultado lo mide Avisar-Resultado
# 1,5 s después, sin congelar el ícono mientras tanto.
function Liberar-Memoria($titulo) {
    $script:LibreAntesMB = Obtener-RamLibreMB
    $script:TituloAviso = $titulo
    Liberar-RamProgramas
    $Espera.Start()
}

# 1,5 s después de liberar
function Avisar-Resultado {
    $Espera.Stop()
    $liberado = [math]::Max(0, (Obtener-RamLibreMB) - $script:LibreAntesMB)
    $Tray.ShowBalloonTip(4000, $script:TituloAviso, ('{0:N0} MB liberados. RAM en uso: {1} %' -f $liberado, (Obtener-PorcentajeRam)), 'Info')
    Actualizar-Icono
}

# Clic derecho > Salir
function Salir {
    $Reloj.Stop()
    $Tray.Visible = $false
    [System.Windows.Forms.Application]::Exit()
}

# ════════ MAIN ════════

function Main {
    # 1. Primero: solo una copia abierta.
    if (Ya-EstaAbierto) {
        [void][System.Windows.Forms.MessageBox]::Show('El monitor de memoria ya está abierto: búscalo junto al reloj (o en la flecha ^).', 'Monitor de memoria')
        return
    }

    # 2. Conectar el ícono, el menú y los relojes con sus acciones.
    Crear-Menu
    $Tray.Add_DoubleClick({ Liberar-Memoria 'Memoria liberada' })
    $Reloj.Interval = $SegundosEntreLecturas * 1000
    $Reloj.Add_Tick({ Actualizar-Icono; Revisar-LimpiezaAutomatica })
    $Espera.Interval = 1500
    $Espera.Add_Tick({ Avisar-Resultado })

    # 3. Mostrar el ícono y arrancar el reloj.
    Actualizar-Icono
    $Tray.Visible = $true
    $Reloj.Start()

    # 4. Explicar en esta ventana cómo se usa, y esperar hasta que elijan Salir.
    Escribir-Encabezado 'MONITOR DE MEMORIA'
    Escribir-Linea 'Estado' 'activo: mira el ícono junto al reloj' 'ok'
    Escribir-Linea 'Liberar memoria' 'doble clic en el ícono'
    Escribir-Linea 'Más opciones' 'clic derecho en el ícono (limpieza automática, Salir...)'
    Escribir-Linea 'Esta ventana' 'déjala minimizada; si la cierras, el monitor se cierra' 'info'
    [System.Windows.Forms.Application]::Run()
    $Candado.ReleaseMutex()
}

Main
