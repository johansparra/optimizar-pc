# Monitor-Memoria-Simple.ps1 - Ícono junto al reloj con el % de RAM en uso. Sin administrador.
# Doble clic en el ícono: liberar memoria. Clic derecho > Salir para cerrarlo.
# Orden del archivo: CONFIGURACIÓN > VISTA > MÉTODOS REUTILIZABLES > ACCIONES > MAIN (al final, como en Java).
Add-Type -AssemblyName System.Windows.Forms, System.Drawing, Microsoft.VisualBasic

# ════════ CONFIGURACIÓN ════════

$SegundosEntreLecturas = 2
$PctNaranja = 70   # desde aquí el ícono se pone naranja
$PctRojo    = 85   # desde aquí, rojo

# Misma lista que Limpiar-Memoria. Solo se toca a estos programas. Nombres sin .exe.
$Programas = 'chrome', 'msedge', 'msedgewebview2', 'firefox', 'brave', 'opera',
    'OUTLOOK', 'olk', 'WINWORD', 'EXCEL', 'POWERPNT', 'ONENOTE', 'MSACCESS',
    'ms-teams', 'Teams', 'lync', 'CiscoCollabHost', 'atmgr', 'Zoom', 'slack',
    'explorer', 'SearchHost', 'StartMenuExperienceHost', 'ShellExperienceHost', 'TextInputHost', 'Widgets',
    'Acrobat', 'AcroRd32', 'Code', 'notepad', 'Spotify', 'WhatsApp', 'Discord'

# Objetos compartidos por todo el archivo (como los atributos de una clase en Java)
$Info  = New-Object Microsoft.VisualBasic.Devices.ComputerInfo   # lee la RAM
$Tray  = New-Object System.Windows.Forms.NotifyIcon              # el ícono junto al reloj
$Reloj = New-Object System.Windows.Forms.Timer                   # actualiza el ícono cada X segundos

# ════════ VISTA (todo lo visual está aquí: el ícono junto al reloj y el texto de esta ventana) ════════

# Cada resultado tiene un tipo; aquí se decide su color.
$Colores = @{ ok = 'Green'; aviso = 'Yellow'; mal = 'Red'; info = 'DarkGray'; normal = 'Gray' }
$Iconos  = @{}   # un dibujo por cada %, se hace una sola vez
$Fuente  = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)

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

# Cuadrito de 16x16 con el número en blanco.
function Dibujar-Icono($pct) {
    if (-not $Iconos[$pct]) {
        $bmp = New-Object System.Drawing.Bitmap(16, 16)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.TextRenderingHint = 'AntiAliasGridFit'
        $g.Clear((Obtener-ColorIcono $pct))
        $centrado = New-Object System.Drawing.StringFormat
        $centrado.Alignment = $centrado.LineAlignment = 'Center'
        $g.DrawString([string][math]::Min($pct, 99), $Fuente, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF(0, 1, 16, 16)), $centrado)
        $Iconos[$pct] = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    }
    $Iconos[$pct]
}

# ════════ MÉTODOS REUTILIZABLES ════════

function Obtener-PorcentajeRam {
    [int](100 - 100 * $Info.AvailablePhysicalMemory / $Info.TotalPhysicalMemory)
}

function Obtener-RamLibreMB {
    $Info.AvailablePhysicalMemory / 1MB
}

# Volver a fijar su propio límite hace que Windows le recorte la RAM que no está usando.
function Liberar-RamProgramas {
    Get-Process -Name $Programas -ErrorAction SilentlyContinue | ForEach-Object { try { $_.MaxWorkingSet = $_.MaxWorkingSet } catch {} }
}

# ════════ ACCIONES (lo que pasa con cada evento) ════════

# Cada X segundos
function Actualizar-Icono {
    $pct = Obtener-PorcentajeRam
    $Tray.Icon = Dibujar-Icono $pct
    $Tray.Text = "RAM en uso: $pct %"
}

# Doble clic en el ícono
function Liberar-Memoria {
    $antes = Obtener-RamLibreMB
    Liberar-RamProgramas
    Start-Sleep -Milliseconds 1500
    $liberado = [math]::Max(0, (Obtener-RamLibreMB) - $antes)
    $Tray.ShowBalloonTip(4000, 'Memoria liberada', ('{0:N0} MB liberados' -f $liberado), 'Info')
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
    # 1. Conectar el ícono con sus acciones.
    $Tray.ContextMenuStrip = New-Object System.Windows.Forms.ContextMenuStrip
    [void]$Tray.ContextMenuStrip.Items.Add('Salir', $null, { Salir })
    $Tray.Add_DoubleClick({ Liberar-Memoria })
    $Reloj.Interval = $SegundosEntreLecturas * 1000
    $Reloj.Add_Tick({ Actualizar-Icono })

    # 2. Mostrar el ícono y arrancar el reloj.
    Actualizar-Icono
    $Tray.Visible = $true
    $Reloj.Start()

    # 3. Explicar en esta ventana cómo se usa, y esperar hasta que elijan Salir.
    Escribir-Encabezado 'MONITOR DE MEMORIA'
    Escribir-Linea 'Estado' 'activo: mira el ícono junto al reloj' 'ok'
    Escribir-Linea 'Liberar memoria' 'doble clic en el ícono'
    Escribir-Linea 'Cerrar el monitor' 'clic derecho en el ícono > Salir'
    Escribir-Linea 'Esta ventana' 'déjala minimizada; si la cierras, el monitor se cierra' 'info'
    [System.Windows.Forms.Application]::Run()
}

Main
