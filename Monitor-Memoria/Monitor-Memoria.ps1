<#
    Monitor-Memoria.ps1  -  Muestra el % de memoria RAM en uso junto al reloj.
    NO necesita permisos de administrador.

    - El ícono muestra el % de RAM en uso: verde (menos de 70 %),
      naranja (70 a 84 %) y rojo (85 % o más).
    - Pasa el mouse por encima para ver el detalle.
    - Doble clic: liberar memoria ahora (igual que Limpiar-Memoria, solo en
      los programas de la lista $Programas).
    - Clic derecho: menú con limpieza automática, Administrador de tareas y Salir.
    - Si no ves el ícono, está escondido en la flecha ^ junto al reloj:
      arrástralo a la barra de tareas y Windows lo recordará.
    - Mientras funciona queda una ventana minimizada llamada "Monitor de
      memoria" en la barra de tareas. No está oculta a propósito: si la
      cierras, el monitor también se cierra.

    No compila código, no instala nada y no se conecta a internet.

    Uso
      Doble clic en Monitor-Memoria.bat. Para cerrarlo: clic derecho en el
      ícono > Salir.
#>

# ─── Ajustes ─────────────────────────────────────────────────────────────────
$Intervalo     = 2        # segundos entre cada actualización del ícono
$UmbralAuto    = 85       # % de RAM a partir del cual limpia sola (si activas la opción)
$EsperaAuto    = 10       # minutos mínimos entre dos limpiezas automáticas
$AutoAlIniciar = $false   # $true para que la limpieza automática arranque activada

# Programas a los que se les libera memoria. Solo estos; todo lo demás se deja
# como está. Puedes añadir o quitar nombres (sin .exe); acepta comodines (*).
$Programas = @(
    # Navegadores
    'chrome', 'msedge', 'msedgewebview2', 'firefox', 'brave', 'opera'
    # Office, correo y reuniones (CiscoCollabHost y atmgr son Webex)
    'OUTLOOK', 'olk', 'WINWORD', 'EXCEL', 'POWERPNT', 'ONENOTE', 'MSACCESS'
    'ms-teams', 'Teams', 'lync', 'CiscoCollabHost', 'atmgr', 'Zoom', 'slack'
    # Escritorio de Windows (explorador, menú Inicio, búsqueda)
    'explorer', 'SearchHost', 'StartMenuExperienceHost', 'ShellExperienceHost', 'TextInputHost', 'Widgets'
    # Otros
    'Acrobat', 'AcroRd32', 'Code', 'notepad', 'Spotify', 'WhatsApp', 'Discord'
)

# ─── Memoria ─────────────────────────────────────────────────────────────────

function Test-EnLista([string]$Nombre) {
    foreach ($patron in $Programas) { if ($Nombre -like $patron) { return $true } }
    return $false
}

function Get-ProgramasALimpiar {
    # Solo procesos de tu sesión que estén en la lista
    $sesion = (Get-Process -Id $PID).SessionId
    Get-Process | Where-Object { $_.SessionId -eq $sesion -and (Test-EnLista $_.ProcessName) }
}

function Clear-MemoriaProceso($Proceso) {
    # Volver a fijar el límite de memoria que el proceso ya tiene hace que Windows
    # le recorte la RAM que no está usando (igual que EmptyWorkingSet).
    try {
        $limite = $Proceso.MaxWorkingSet
        if ($null -eq $limite) { return $false }
        $Proceso.MaxWorkingSet = $limite
        return $true
    } catch {
        return $false
    }
}

function Get-Ram {
    if (-not $script:InfoPC) { $script:InfoPC = New-Object Microsoft.VisualBasic.Devices.ComputerInfo }
    $total = [double]$script:InfoPC.TotalPhysicalMemory
    $disponible = [double]$script:InfoPC.AvailablePhysicalMemory
    [pscustomobject]@{
        Total      = $total
        Disponible = $disponible
        EnUso      = $total - $disponible
        Pct        = 100 * ($total - $disponible) / $total
    }
}

function Format-Tamano([double]$Bytes) {
    if ([math]::Abs($Bytes) -ge 1GB) { return '{0:N1} GB' -f ($Bytes / 1GB) }
    return '{0:N0} MB' -f ($Bytes / 1MB)
}

# ─── Ícono ───────────────────────────────────────────────────────────────────

function Get-IconoPorcentaje([int]$Pct) {
    # Dibuja el número en un cuadrito de color. Se guarda cada ícono ya dibujado
    # para no crear uno nuevo cada 2 segundos.
    if ($script:Iconos.ContainsKey($Pct)) { return $script:Iconos[$Pct] }

    $tam = $script:TamIcono
    $bmp = New-Object System.Drawing.Bitmap($tam, $tam)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    $color = if ($Pct -ge 85) { [System.Drawing.Color]::FromArgb(200, 40, 40) }
             elseif ($Pct -ge 70) { [System.Drawing.Color]::FromArgb(210, 105, 0) }
             else { [System.Drawing.Color]::FromArgb(20, 125, 65) }
    $fondo = New-Object System.Drawing.SolidBrush($color)
    $d = [math]::Max(4, [int]($tam / 2))   # diámetro de las esquinas redondeadas
    $forma = New-Object System.Drawing.Drawing2D.GraphicsPath
    $forma.AddArc(0, 0, $d, $d, 180, 90)
    $forma.AddArc($tam - $d - 1, 0, $d, $d, 270, 90)
    $forma.AddArc($tam - $d - 1, $tam - $d - 1, $d, $d, 0, 90)
    $forma.AddArc(0, $tam - $d - 1, $d, $d, 90, 90)
    $forma.CloseFigure()
    $g.FillPath($fondo, $forma)

    # El número se dibuja como figura para poder ajustarlo y centrarlo exacto
    $familia = New-Object System.Drawing.FontFamily('Segoe UI')
    $numero = New-Object System.Drawing.Drawing2D.GraphicsPath
    $numero.AddString([string][math]::Min($Pct, 99), $familia, [int][System.Drawing.FontStyle]::Bold,
        [single]($tam * 0.8), (New-Object System.Drawing.PointF(0, 0)), [System.Drawing.StringFormat]::GenericTypographic)
    $caja = $numero.GetBounds()
    $escala = [math]::Min(1, [math]::Min(($tam - 3) / $caja.Width, ($tam * 0.62) / $caja.Height))
    $ajuste = New-Object System.Drawing.Drawing2D.Matrix
    $ajuste.Translate(($tam - $caja.Width * $escala) / 2, ($tam - $caja.Height * $escala) / 2)
    $ajuste.Scale($escala, $escala)
    $ajuste.Translate(-$caja.X, -$caja.Y)
    $numero.Transform($ajuste)
    $g.FillPath([System.Drawing.Brushes]::White, $numero)

    $icono = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    $g.Dispose(); $familia.Dispose(); $numero.Dispose(); $ajuste.Dispose(); $fondo.Dispose(); $forma.Dispose(); $bmp.Dispose()
    $script:Iconos[$Pct] = $icono
    return $icono
}

# ─── Monitor ─────────────────────────────────────────────────────────────────

function Update-Monitor {
    try {
        $ram = Get-Ram
        $pct = [int][math]::Round($ram.Pct)
        if ($pct -ne $script:UltimoPct) {
            $script:Icono.Icon = Get-IconoPorcentaje $pct
            $script:UltimoPct = $pct
        }
        $detalle = '{0} de {1} · libre {2}' -f (Format-Tamano $ram.EnUso), (Format-Tamano $ram.Total), (Format-Tamano $ram.Disponible)
        $texto = "Memoria RAM: $pct % en uso`n$detalle"
        if ($texto.Length -gt 63) { $texto = $texto.Substring(0, 63) }   # límite de Windows
        $script:Icono.Text = $texto
        $script:ItemEstado.Text = "RAM $pct % · $detalle"

        $minutos = ((Get-Date) - $script:UltimaAuto).TotalMinutes
        if ($script:ItemAuto.Checked -and $pct -ge $UmbralAuto -and $minutos -ge $EsperaAuto) {
            $script:UltimaAuto = Get-Date
            Invoke-Limpieza -Automatica
        }
    } catch { }
}

function Invoke-Limpieza([switch]$Automatica) {
    try {
        $script:AntesLimpieza = Get-Ram
        $script:TituloAviso = if ($Automatica) { 'Limpieza automática de memoria' } else { 'Memoria liberada' }
        foreach ($p in Get-ProgramasALimpiar) { [void](Clear-MemoriaProceso $p) }

        # El resultado se mide 1,5 s después, sin congelar el ícono mientras tanto
        $espera = New-Object System.Windows.Forms.Timer
        $espera.Interval = 1500
        $espera.Add_Tick({
            param($temporizador, $evento)
            $temporizador.Stop()
            $temporizador.Dispose()
            $ahora = Get-Ram
            $liberado = $ahora.Disponible - $script:AntesLimpieza.Disponible
            $mensaje = if ($liberado -ge 50MB) {
                'Se liberaron {0}. RAM en uso: {1:N0} %' -f (Format-Tamano $liberado), $ahora.Pct
            } else {
                'No había mucha memoria que liberar. RAM en uso: {0:N0} %' -f $ahora.Pct
            }
            $script:Icono.ShowBalloonTip(4000, $script:TituloAviso, $mensaje, [System.Windows.Forms.ToolTipIcon]::Info)
            Update-Monitor
        })
        $espera.Start()
    } catch {
        $script:Icono.ShowBalloonTip(5000, 'Monitor de memoria', "No se pudo liberar memoria: $($_.Exception.Message)", [System.Windows.Forms.ToolTipIcon]::Warning)
    }
}

function Stop-Monitor {
    $script:Reloj.Stop()
    $script:Icono.Visible = $false
    $script:Icono.Dispose()
    $script:Contexto.ExitThread()
}

function Start-Monitor {
    if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
        Write-Host ''
        Write-Host '  PowerShell está restringido en este equipo por política de la empresa;' -ForegroundColor Red
        Write-Host '  el monitor de memoria no se ejecuta aquí.' -ForegroundColor Red
        Read-Host '  Presiona Enter para cerrar'
        return
    }

    Add-Type -AssemblyName System.Windows.Forms, System.Drawing, Microsoft.VisualBasic

    # Solo una copia abierta a la vez
    $script:Candado = New-Object System.Threading.Mutex($false, 'Local\MonitorMemoriaRAM')
    $esPrimera = $false
    try { $esPrimera = $script:Candado.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $esPrimera = $true }
    if (-not $esPrimera) {
        [void][System.Windows.Forms.MessageBox]::Show('El monitor de memoria ya está abierto: búscalo junto al reloj (o en la flecha ^).', 'Monitor de memoria')
        return
    }

    $Host.UI.RawUI.WindowTitle = 'Monitor de memoria (no cierres esta ventana)'
    Write-Host ''
    Write-Host '  Monitor de memoria activo: mira el ícono junto al reloj.' -ForegroundColor Green
    Write-Host '  Esta ventana puede quedarse minimizada. Si la cierras, el monitor se cierra.'
    Write-Host '  Para salir: clic derecho en el ícono > Salir.'

    [System.Windows.Forms.Application]::EnableVisualStyles()
    $dpi = (Get-ItemProperty 'HKCU:\Control Panel\Desktop\WindowMetrics' -ErrorAction SilentlyContinue).AppliedDPI
    if (-not $dpi) { $dpi = 96 }
    $script:TamIcono = [int][math]::Round(16 * $dpi / 96)
    $script:Iconos = @{}
    $script:UltimoPct = -1
    $script:UltimaAuto = [datetime]::MinValue

    # Menú del clic derecho
    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    $script:ItemEstado = $menu.Items.Add('RAM')
    $script:ItemEstado.Enabled = $false
    [void]$menu.Items.Add('-')
    $itemLimpiar = $menu.Items.Add('Liberar memoria ahora')
    $itemLimpiar.Font = New-Object System.Drawing.Font($itemLimpiar.Font, [System.Drawing.FontStyle]::Bold)
    $script:ItemAuto = $menu.Items.Add("Liberar sola al pasar de $UmbralAuto %")
    $script:ItemAuto.CheckOnClick = $true
    $script:ItemAuto.Checked = $AutoAlIniciar
    $itemTareas = $menu.Items.Add('Abrir Administrador de tareas')
    [void]$menu.Items.Add('-')
    $itemSalir = $menu.Items.Add('Salir')

    $script:Icono = New-Object System.Windows.Forms.NotifyIcon
    $script:Icono.ContextMenuStrip = $menu
    $script:Contexto = New-Object System.Windows.Forms.ApplicationContext

    $itemLimpiar.Add_Click({ Invoke-Limpieza })
    $script:Icono.Add_DoubleClick({ Invoke-Limpieza })
    $itemTareas.Add_Click({ Start-Process taskmgr.exe })
    $itemSalir.Add_Click({ Stop-Monitor })

    $script:Reloj = New-Object System.Windows.Forms.Timer
    $script:Reloj.Interval = $Intervalo * 1000
    $script:Reloj.Add_Tick({ Update-Monitor })

    Update-Monitor
    $script:Icono.Visible = $true
    $script:Reloj.Start()

    [System.Windows.Forms.Application]::Run($script:Contexto)
    $script:Candado.ReleaseMutex()
}

# Arranca el monitor (salvo que el archivo se cargue con ". .\Monitor-Memoria.ps1" para pruebas)
if ($MyInvocation.InvocationName -ne '.') { Start-Monitor }
