# Análisis con PSScriptAnalyzer

## Estado actual

**0 avisos.** Los 4 scripts (Limpiar-Memoria 1.0.2, Monitor-Memoria 1.0.2, Optimizar-Internet 1.1.0 y Optimizar-PC 1.2.0) pasan todas las reglas normales de PSScriptAnalyzer 1.25.0, en todos los niveles (error, aviso y sugerencia), y la revisión de compatibilidad con PowerShell 5.1.

| Fecha | Versión de los scripts | Avisos | Lista completa |
| --- | --- | ---: | --- |
| 2026-11-19 23:22 | 1.0.1 | 138 | [PSScriptAnalyzer_2026-11-19_2322.md](PSScriptAnalyzer_2026-11-19_2322.md) |
| 2026-11-19 23:39 | 1.0.2 | 0 | [PSScriptAnalyzer_2026-11-19_2339.md](PSScriptAnalyzer_2026-11-19_2339.md) |
| 2026-11-20 23:18 | 1.0.2 y 1.1.0 (Optimizar-Internet y Optimizar-PC) | 0 | [PSScriptAnalyzer_2026-11-20_2318.md](PSScriptAnalyzer_2026-11-20_2318.md) |

## Cómo se resolvió cada aviso

| Regla | Cuántos | Qué decía | Qué se hizo |
| --- | ---: | --- | --- |
| `PSAvoidUsingPositionalParameters` | 64 | Llamadas con 3 o más argumentos sin el nombre del parámetro. | Del 3.er argumento en adelante va con nombre: `Write-Line 'Modo' 'normal' -tipo 'info'`. |
| `PSAvoidUsingWriteHost` | 45 | `Write-Host` solo escribe en pantalla. | Se deja, porque los colores en la consola son la interfaz. Queda marcado como intencional al inicio de cada script (`SuppressMessageAttribute` con su motivo). Cambiarlo por `Write-Output` quitaría los colores. |
| `PSUseSingularNouns` | 16 | Nombres de función en plural. | Renombradas en singular (tabla de abajo). |
| `PSUseShouldProcessForStateChangingFunctions` | 11 | Funciones que cambian cosas sin soporte para `-WhatIf`. | Marcado como intencional: los scripts se abren con doble clic y nadie puede pasarles `-WhatIf`. Agregarlo serían líneas que nunca se usan. |
| `PSAvoidUsingEmptyCatchBlock` | 2 | `catch {}` vacío. | El error se sigue ignorando a propósito, pero ahora deja una nota con `Write-Verbose`, que solo se ve si se corre con `-Verbose`. |

### Funciones renombradas

Solo se usan dentro de su propio script. Donde quitar la "s" no tenía sentido (`Dns`, `Tweaks`…) se eligió un nombre más claro. Se comprobó que ninguno choca con un comando de Windows.

| Script | Antes | Ahora |
| --- | --- | --- |
| Limpiar-Memoria | `Get-SessionPrograms` | `Get-SessionProgram` |
| Optimizar-Internet | `Get-PhysicalAdapters` | `Get-PhysicalAdapter` |
| Optimizar-Internet | `Invoke-CmdLines` | `Invoke-CmdLine` |
| Optimizar-Internet | `Test-Dns` | `Test-DnsResolution` |
| Optimizar-Internet | `Set-TcpTweaks` | `Set-TcpSetting` |
| Optimizar-Internet | `Set-StaticDns` | `Set-StaticDnsServer` |
| Optimizar-PC | `Remove-OldFiles` | `Remove-OldFile` |
| Optimizar-PC | `Remove-EmptyFolders` | `Remove-EmptyFolder` |
| Optimizar-PC | `Get-ChromiumCaches` | `Get-ChromiumCachePath` |
| Optimizar-PC | `Show-StartupPrograms` | `Show-StartupProgram` |
| Optimizar-PC | `Clear-Thumbnails` | `Clear-ThumbnailCache` |
| Optimizar-PC | `Clear-ErrorReports` | `Clear-ErrorReport` |
| Optimizar-PC | `Clear-WindowsCookies` | `Clear-WindowsCookie` |
| Optimizar-PC | `Clear-RecentFiles` | `Clear-RecentFile` |
| Optimizar-PC | `Clear-WindowsComponents` | `Clear-ComponentStore` |
| Optimizar-PC | `Optimize-Disks` | `Optimize-Disk` |

## Cómo se comprobó que siguen funcionando igual

Todo en PowerShell 5.1 (el que usan los `.bat`), comparando la versión anterior (1.0.1) con la nueva (1.0.2):

| Prueba | Resultado |
| --- | --- |
| PSScriptAnalyzer, con y sin la revisión de PowerShell 5.1 | 0 avisos |
| `Test-PSScriptFileInfo`, UTF-8 con BOM y finales de línea CRLF | los 4 bien |
| Se leen sin errores de sintaxis en PowerShell 5.1 | los 4 |
| Cada llamada recibe los mismos valores en los mismos parámetros (comparación del código sin ejecutarlo, 352 llamadas) | iguales; lo único nuevo son los 2 `Write-Verbose` |
| Limpiar-Memoria completo | misma salida; solo cambian los números de RAM |
| Monitor-Memoria: lectura de RAM, dibujo del ícono y liberar memoria | igual |
| Optimizar-Internet: diagnóstico (adaptadores, Wi-Fi, servicios, pings, DNS) y ejecución de comandos | igual |
| Optimizar-PC: revisión del equipo y borrado en una carpeta de prueba (archivos viejos, uno en uso, una carpeta que no queda vacía, una caché) | mismos archivos borrados y mismo reporte |
| PowerShell restringido (como en una laptop de empresa bloqueada) | los 4 avisan y salen sin hacer nada |
| `Get-Help` de cada script | igual |

**No se probó en el equipo real:** Optimizar-PC y Optimizar-Internet completos (borrarían tus archivos y reiniciarían la red), el ícono de Monitor-Memoria junto al reloj, ni el mantenimiento que pide administrador. En esas partes solo cambiaron nombres y la forma de pasar los argumentos, y eso lo cubre la comparación de llamadas.

## Compatibilidad con PowerShell 5.1

Los `.bat` abren los scripts con `powershell.exe` (PowerShell 5.1), pero en el PC personal todo se prueba con PowerShell 7, así que algo que solo existe en 7 pasaría las pruebas y fallaría en la laptop. Por eso las reglas `PSUseCompatibleSyntax` y `PSUseCompatibleCommands` revisan los scripts contra Windows 10 Pro con PowerShell 5.1.

Para comprobar que esas reglas sí detectan el problema, se probaron con un script de prueba que usaba `??`, `ForEach-Object -Parallel` y `Join-String` (las tres solo existen en PowerShell 7) y avisaron de las tres.

## Cómo repetirlo

Las reglas están en [PSScriptAnalyzerSettings.psd1](PSScriptAnalyzerSettings.psd1). La skill `actualizar-version-scripts` las corre antes de cada commit, y no debe salir ningún aviso.

Para guardar una lista completa nueva, pega esto en PowerShell 7 desde la raíz del repo. Crea `audit/PSScriptAnalyzer_AAAA-MM-DD_HHMM.md` con la fecha y hora; las listas anteriores se quedan como historial.

```powershell
$ps1 = Get-ChildItem -Recurse -Filter *.ps1 | Where-Object FullName -notmatch '\\RAMMap\\'
$hallazgos = $ps1 | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName }
$marcados = $ps1 | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -SuppressedOnly } | Group-Object RuleName
$marcados = if ($marcados) { ($marcados | ForEach-Object { '{0} {1}' -f $_.Count, $_.Name }) -join ', ' } else { 'ninguno' }
$commit = git rev-parse --short HEAD
if (git status --porcelain -- '*.ps1') { $commit += ' + cambios sin commit' }
$fecha = Get-Date
$tipo = @{ Error = 'Error'; Warning = 'Aviso'; Information = 'Sugerencia' }
$md = '# Lista completa de PSScriptAnalyzer', '',
    ('**Fecha:** {0:yyyy-MM-dd HH:mm} · **PSScriptAnalyzer:** {1} · **Commit:** `{2}`' -f $fecha, (Get-Module PSScriptAnalyzer).Version, $commit), '',
    ('**Hallazgos:** {0} · **Marcados como intencionales en el código:** {1}' -f @($hallazgos).Count, $marcados), '',
    'Qué significa cada regla y cómo se resolvió: [PSScriptAnalyzer.md](PSScriptAnalyzer.md).'
if (-not $hallazgos) { $md += '', 'Sin hallazgos.' }
foreach ($g in $hallazgos | Group-Object ScriptName) {
    $avisos = @($g.Group | Where-Object Severity -eq 'Warning').Count
    $md += '', ('## {0}: {1} avisos, {2} sugerencias' -f $g.Name, $avisos, ($g.Count - $avisos)), '',
        '| Línea | Tipo | Regla | Código |', '| ---: | --- | --- | --- |'
    $md += $g.Group | Sort-Object Line | ForEach-Object {
        '| {0} | {1} | {2} | `{3}` |' -f $_.Line, $tipo["$($_.Severity)"], $_.RuleName, (($_.Extent.Text -split "`n")[0].Trim() -replace '\|', '\|')
    }
}
$md | Set-Content ('audit\PSScriptAnalyzer_{0:yyyy-MM-dd_HHmm}.md' -f $fecha) -Encoding utf8
```
