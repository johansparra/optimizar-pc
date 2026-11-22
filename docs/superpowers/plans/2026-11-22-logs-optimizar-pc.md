# Logs en Optimizar-PC — plan de implementación

**Cambio al aprobarlo (2026-11-22):** el usuario pidió sin pruebas y con log en los 4 scripts (Monitor-Memoria solo a alto nivel). Se ejecutó sin la Task 1 de pruebas ni la guarda para cargar el script con `.`; la función quedó como `Write-LogLine` y la variable como `$script:ArchivoLog`. El diseño actualizado está en el spec.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Optimizar-PC escribe un `.log` por ejecución en `log\`, con niveles, rotación (hoy y ayer, 3 por día) y tope de 10 MB.

**Architecture:** Una sección nueva `LOG` dentro de `Optimizar-PC.ps1` (Start-Log / Write-Log / Stop-Log) que después se copiará idéntica a Optimizar-Internet y Limpiar-Memoria. Lo que sale en pantalla llega al log enganchando las funciones de VISTA; DEBUG se agrega en los pocos métodos que borran o ejecutan cosas. Una guarda al final permite cargar el script con `.` para probarlo sin que corra la limpieza.

**Tech Stack:** Windows PowerShell 5.1 (también 7), `System.IO.StreamWriter`. Prueba: script de PowerShell con comprobaciones simples (el Pester del equipo es 3.4; no hace falta).

**Spec:** [docs/superpowers/specs/2026-11-22-logs-optimizar-pc-design.md](../specs/2026-11-22-logs-optimizar-pc-design.md)

## Global Constraints

- Compatible con PowerShell 5.1 y sin administrador. Sin `Add-Type`, `-ExecutionPolicy Bypass`, ventanas ocultas, `-EncodedCommand`, IEX ni descargas.
- Valores por defecto en CONFIGURACIÓN: `$NivelLog = 'INFO'`, `$PrefijoLog = 'op-pc'`, `$LogMaxMB = 10`.
- Carpeta: `<carpeta del .ps1>\log`. Nombre: `<prefijo>-yyyy-MM-dd_HH-mm-ss.log`. Codificación UTF-8 con BOM (Bloc de notas muestra bien las tildes).
- Línea: `yyyy-MM-dd HH:mm:ss.fff [NIVEL] Cadena | mensaje`, con el nivel rellenado a 5 caracteres (`[INFO ]`, `[WARN ]`, `[DEBUG]`, `[ERROR]`).
- Niveles: DEBUG < INFO < WARN < ERROR. Tipos de pantalla: `ok`, `info`, `normal` → INFO; `aviso` → WARN; `mal` → ERROR.
- El log nunca detiene la limpieza. Nombres de archivos solo en DEBUG.
- La sección LOG debe quedar idéntica para copiarla a los otros scripts: nada de `op-pc` ni `Optimizar-PC` escrito dentro de ella (usar `$PrefijoLog` y el nombre de `$PSCommandPath`).
- Funciones en inglés con verbos aprobados y en singular; comentarios y mensajes en español.

## Review Focus

1. **Archivos ajenos en `log\`** (cualquiera que no cumpla exactamente el patrón del nombre): la rotación no los borra nunca. → prueba 1.
2. **No se puede crear `log\`** (carpeta de solo lectura, ruta inválida): aviso amarillo en pantalla, `Write-Log` no hace nada y el script sigue. → prueba 5.
3. **DEBUG con miles de archivos de caché**: al pasar `$LogMaxMB` se cortan solo las DEBUG, con una única línea WARN, y las INFO siguen llegando. → prueba 3.
4. **Ventana cerrada a mitad de la ejecución**: lo ya escrito está en el disco (se puede leer con el archivo todavía abierto). → prueba 2.
5. **Archivo en uso durante la limpieza**: línea DEBUG con la ruta y el motivo, y la limpieza sigue. → prueba 4.

---

### Task 1: Sección LOG y enganches en Optimizar-PC.ps1

**Files:**

- Create: `tests/Optimizar-PC.Log.Tests.ps1`
- Modify: `Optimizar-PC/Optimizar-PC.ps1` — `.NOTES` (l. 16), CONFIGURACIÓN (l. 31-40), sección nueva `LOG` entre CONFIGURACIÓN y VISTA, `Write-Title` (l. 58), `Write-Line` (l. 65), `Write-Bar` (l. 71), `Remove-OldFile` (l. 84), `Remove-EmptyFolder` (l. 113), `Invoke-Tool` (l. 130), `Set-DiskCleanupOption` (l. 298), `Invoke-DiskCleanup` (l. 314), `Confirm-WindowsRepair` (l. 358), `Main` y la llamada final (l. 384-443)

**Interfaces:**

- Produces:
  - `Start-Log($carpeta)`: reinicia `$script:LogLleno = $false`, crea la carpeta, abre `$script:Log` (StreamWriter, `AutoFlush = $true`, append) en `$script:LogRuta`, escribe el encabezado y rota. Si algo falla: `$script:Log = $null` y `Write-Line 'Log' "no se pudo crear: <motivo>" -tipo 'aviso'`.
  - `Write-Log($nivel, $texto)`: no hace nada si `$script:Log` es `$null` o el nivel está por debajo de `$NivelLog`.
  - `Stop-Log`: escribe INFO `Fin (N s)`, cierra el archivo y deja `$script:Log = $null`. No falla si no hay log.
  - `$script:LogRuta`: ruta del archivo actual (la usan las pruebas).

- [ ] **Step 1: Escribir la prueba `tests/Optimizar-PC.Log.Tests.ps1`**

Lo primero que hace es comprobar que la guarda existe; sin ella, cargar el script ejecutaría la limpieza real.

```powershell
# Prueba del bloque LOG de Optimizar-PC. Ejecutar (sin admin):
#   powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Optimizar-PC.Log.Tests.ps1
$ps1 = "$PSScriptRoot\..\Optimizar-PC\Optimizar-PC.ps1"
if (-not (Select-String -LiteralPath $ps1 -SimpleMatch "InvocationName -ne '.'" -Quiet)) { throw 'Falta la guarda: cargar el script ejecutaría la limpieza.' }
. $ps1
$script:fallas = 0
function Test-Caso($nombre, $ok) { if ($ok) { Write-Host "ok    $nombre" -ForegroundColor Green } else { Write-Host "FALLA $nombre" -ForegroundColor Red; $script:fallas++ } }
$base = Join-Path $env:TEMP "op-pc-pruebas-$PID"
$hoy = Get-Date -Format 'yyyy-MM-dd'; $ayer = (Get-Date).AddDays(-1).ToString('yyyy-MM-dd'); $viejo = (Get-Date).AddDays(-2).ToString('yyyy-MM-dd')

# 1. Rotación: borra antes de ayer, deja los 3 más nuevos por día (contando el nuevo) y no toca ajenos
$dir = "$base\rotacion"; $null = New-Item $dir -ItemType Directory -Force
"op-pc-${viejo}_10-00-00.log", "op-pc-${ayer}_01-00-00.log", "op-pc-${ayer}_02-00-00.log", "op-pc-${ayer}_03-00-00.log",
"op-pc-${ayer}_04-00-00.log", "op-pc-${hoy}_00-00-01.log", "op-pc-${hoy}_00-00-02.log", "op-pc-${hoy}_00-00-03.log",
'notas.txt', 'op-pc-copia.log' | ForEach-Object { Set-Content "$dir\$_" 'x' }
$NivelLog = 'INFO'; Start-Log $dir; Stop-Log
$quedan = (Get-ChildItem $dir).Name
Test-Caso 'rotación borra antes de ayer'        (-not ($quedan -like "op-pc-${viejo}*"))
Test-Caso 'rotación deja 3 de ayer'             ((@($quedan -like "op-pc-${ayer}*").Count -eq 3) -and -not ($quedan -contains "op-pc-${ayer}_01-00-00.log"))
Test-Caso 'rotación deja 3 de hoy con el nuevo' ((@($quedan -like "op-pc-${hoy}*").Count -eq 3) -and -not ($quedan -contains "op-pc-${hoy}_00-00-01.log"))
Test-Caso 'rotación no toca archivos ajenos'    (($quedan -contains 'notas.txt') -and ($quedan -contains 'op-pc-copia.log'))

# 2. Formato, nivel, cadena de funciones, escritura inmediata y BOM
$dir = "$base\formato"; $NivelLog = 'INFO'; Start-Log $dir
function Clear-Prueba { Write-Line 'Prueba' 'canción' -tipo 'aviso'; Write-Log DEBUG 'no debe salir' }
Clear-Prueba
$lineas = Get-Content $script:LogRuta -Encoding UTF8        # el archivo sigue abierto
Test-Caso 'encabezado con script y nivel'        ($lineas[0] -match 'Optimizar-PC .*nivel: INFO')
Test-Caso 'formato, WARN y nombre de función'     (@($lineas -match '^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d{3} \[WARN \] Clear-Prueba \| Prueba: canción$').Count -eq 1)
Test-Caso 'DEBUG no sale con nivel INFO'         (-not ($lineas -match 'no debe salir'))
Stop-Log
Test-Caso 'cierra con Fin'                       ((Get-Content $script:LogRuta -Encoding UTF8)[-1] -match '\[INFO \] .* \| Fin \(')
Test-Caso 'UTF-8 con BOM'                        ((-join ([IO.File]::ReadAllBytes($script:LogRuta)[0..2] | ForEach-Object { '{0:X2}' -f $_ })) -eq 'EFBBBF')

# 3. Tope: solo se cortan las DEBUG, con un único aviso
$dir = "$base\tope"; $NivelLog = 'DEBUG'; $LogMaxMB = 0.01; Start-Log $dir
1..500 | ForEach-Object { Write-Log DEBUG ('x' * 100) }
Write-Log INFO 'después del tope'
Stop-Log; $LogMaxMB = 10
$lineas = Get-Content $script:LogRuta -Encoding UTF8
Test-Caso 'tope: el archivo no crece de más'      ((Get-Item $script:LogRuta).Length -lt (0.01MB + 2KB))
Test-Caso 'tope: un solo aviso WARN'              (@($lineas -match '\[WARN \]').Count -eq 1)
Test-Caso 'tope: INFO sigue llegando'             (@($lineas -match 'después del tope').Count -eq 1)

# 4. Remove-OldFile en DEBUG: lista lo borrado y lo que estaba en uso
$dir = "$base\limpieza"; $datos = "$dir\datos"; $null = New-Item $datos -ItemType Directory -Force
'a.tmp', 'b.tmp' | ForEach-Object { Set-Content "$datos\$_" 'x'; (Get-Item "$datos\$_").LastWriteTime = (Get-Date).AddDays(-2) }
$candado = [IO.File]::Open("$datos\b.tmp", 'Open', 'Read', 'None')
$NivelLog = 'DEBUG'; Start-Log "$dir\log"
function Clear-Prueba2 { Remove-OldFile 'Prueba' $datos -horas 24 }
Clear-Prueba2
Stop-Log; $candado.Dispose()
$lineas = Get-Content $script:LogRuta -Encoding UTF8
Test-Caso 'DEBUG anota lo borrado'                (@($lineas -match '\[DEBUG\] Clear-Prueba2>Remove-OldFile \| Borrado .*a\.tmp').Count -eq 1)
Test-Caso 'DEBUG anota lo que estaba en uso'      (@($lineas -match '\[DEBUG\] Clear-Prueba2>Remove-OldFile \| No se pudo borrar .*b\.tmp').Count -eq 1)
Test-Caso 'la línea de pantalla también llega'    (@($lineas -match '\[INFO \] Clear-Prueba2>Remove-OldFile \| Prueba: 1 archivos').Count -eq 1)

# 5. Sin carpeta posible: avisa y sigue sin log
Set-Content "$base\archivo" 'x'
$sinError = $true; try { Start-Log "$base\archivo\log"; Write-Log INFO 'x'; Stop-Log } catch { $sinError = $false }
Test-Caso 'sin carpeta: no falla y no hay log'    ($sinError -and $null -eq $script:Log)

Remove-Item $base -Recurse -Force
if ($script:fallas) { Write-Host "$script:fallas fallas" -ForegroundColor Red; exit 1 } else { Write-Host 'Todo bien' -ForegroundColor Green }
```

- [ ] **Step 2: Correr la prueba y ver que falla**

Run: `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Optimizar-PC.Log.Tests.ps1`
Expected: termina con `Falta la guarda: cargar el script ejecutaría la limpieza.` (no corre la limpieza).

- [ ] **Step 3: Implementar en `Optimizar-PC/Optimizar-PC.ps1`**

  - CONFIGURACIÓN: `$NivelLog`, `$PrefijoLog`, `$LogMaxMB` con los valores de Global Constraints y un comentario de una línea cada uno (DEBUG anota cada archivo borrado: usarlo solo para revisar fallas).
  - Sección `# ════════ LOG ════════` entre CONFIGURACIÓN y VISTA con `Start-Log`, `Write-Log`, `Stop-Log`. Actualizar el orden en `.NOTES`.
  - `Start-Log`: encabezado INFO `<nombre del .ps1> <versión> | admin: sí/no | nivel: <NivelLog> | <Caption y Version de Win32_OperatingSystem> | PowerShell <versión>`. La versión sale de la línea `.VERSION` del propio archivo (`Select-String -LiteralPath $PSCommandPath`). La rotación se hace **después** de abrir el archivo nuevo y solo sobre los nombres que cumplen `^<prefijo escapado>-(\d{4}-\d\d-\d\d)_\d\d-\d\d-\d\d\.log$`: se borran las fechas `-lt` ayer (comparación de texto `yyyy-MM-dd`) y, por fecha, todo menos los 3 más nuevos por nombre. Cada borrado deja una línea DEBUG.
  - `Write-Log`: orden de las comprobaciones: sin log → salir; nivel bajo → salir; DEBUG con `$script:Log.BaseStream.Length -ge $LogMaxMB * 1MB` → la primera vez marca `$script:LogLleno` y escribe WARN `Se llegó al tope de <N> MB: se dejan de anotar las líneas DEBUG`, y sale. La cadena de funciones solo se calcula si la línea se va a escribir:

    ```powershell
    $cadena = @(Get-PSCallStack | Select-Object -Skip 1 -ExpandProperty FunctionName |
        Where-Object { $_ -notmatch '^(Write-|Main$|<ScriptBlock>)' })
    [array]::Reverse($cadena)
    if (-not $cadena) { $cadena = 'Main' }
    # línea: '{0:yyyy-MM-dd HH:mm:ss.fff} [{1,-5}] {2} | {3}' -f (Get-Date), $nivel, ($cadena -join '>'), $texto
    ```

  - Enganches de VISTA:
    - `Write-Title`: INFO `=== <texto> ===`.
    - `Write-Line`: `<nombre>: <resultado>` (solo la parte que no esté vacía), con el nivel según el tipo.
    - `Write-Bar`: INFO `<nombre>: <pct> % <detalle>`.
  - DEBUG en los métodos:
    - `Remove-OldFile`: al inicio, `Busca en <rutas> lo anterior a <límite>: <N> elementos`; por archivo, `Borrado <ruta> (<KB> KB)`; en el `catch`, `No se pudo borrar <ruta>: <mensaje de la excepción>`.
    - `Remove-EmptyFolder`: el `Write-Verbose` pasa a `Write-Log DEBUG "Carpeta que se deja: $_"`.
    - `Invoke-Tool`: el comando con sus argumentos, antes de lanzarlo.
    - `Invoke-DiskCleanup`: `cleanmgr.exe /sagerun:1`.
    - `Set-DiskCleanupOption`, en su `catch`: el nombre de la opción y el motivo.
  - `Confirm-WindowsRepair`: guarda la respuesta, la anota con INFO `Reparar Windows: respondió '<r>'` y devuelve lo mismo que hoy.
  - `Main`: `Start-Log (Join-Path $PSScriptRoot 'log')` justo después de `Write-Header`.
  - Final del archivo, en lugar de `Main`:

    ```powershell
    # Con ". .\Optimizar-PC.ps1" (las pruebas) solo se cargan las funciones; no corre la limpieza.
    if ($MyInvocation.InvocationName -ne '.') {
        try { Main }
        catch { Write-Log ERROR "Error inesperado: $_`n$($_.ScriptStackTrace)"; throw }
        finally { Stop-Log }
    }
    ```

- [ ] **Step 4: Correr la prueba y ver que pasa**

Run: `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Optimizar-PC.Log.Tests.ps1`
Expected: todas las líneas `ok` y al final `Todo bien`. Repetir con `pwsh` si está instalado.

### Task 2: Versión, documentación y prueba real

**Files:**

- Modify: `.gitignore`, `README.md` (l. 37-52 y Notas), `Optimizar-PC/Optimizar-PC.ps1` (PSScriptInfo), `CHANGELOG.md`

- [ ] **Step 1: `.gitignore`**: agregar `log/` con un comentario de una línea (los logs de las pruebas no se suben).
- [ ] **Step 2: `README.md`**:
  - en "Cómo están hechos los `.ps1`", agregar la sección LOG al orden;
  - en "Dos cosas que hay que mantener iguales", agregar que la sección LOG es idéntica en los scripts que la tengan;
  - en Notas, un punto **Logs**: dónde quedan, cómo pasar a DEBUG (`$NivelLog`), rotación, tope de 10 MB, y que en DEBUG salen nombres de archivos.
- [ ] **Step 3: Skill `actualizar-version-scripts`**: Optimizar-PC 1.4.0, con nota en `.RELEASENOTES` y CHANGELOG. Debe terminar sin avisos de `Test-PSScriptFileInfo` ni de PSScriptAnalyzer (incluida la compatibilidad con 5.1).
- [ ] **Step 4: Prueba real sin admin**. VS Code corre elevado, así que se abre con `explorer.exe Optimizar-PC\Optimizar-PC.bat`. Hacer limpieza real tarda hasta unos 3 minutos por el Liberador; la ventana queda en `pause` para que el usuario la cierre. Esperar a que exista un `Optimizar-PC\log\op-pc-*.log` cuya última línea contenga `| Fin (`.
  Expected: encabezado con `admin: no` y `nivel: INFO`, las secciones `=== Limpieza ===` … `=== Listo ===`, ninguna línea `[DEBUG]`, y el archivo pesa menos de 50 KB.
- [ ] **Step 5: Correr otra vez la prueba de Task 1** (Expected: `Todo bien`) y preguntar al usuario si se hace el commit `Optimizar-PC 1.4.0: logs con niveles, rotación y tope de 10 MB`.
