# Lista completa de PSScriptAnalyzer

**Fecha:** 2026-11-19 23:22 · **PSScriptAnalyzer:** 1.25.0 · **Commit:** `c0d823e`

Qué significa cada regla y por qué se acepta: [PSScriptAnalyzer.md](PSScriptAnalyzer.md).

## Limpiar-Memoria.ps1: 15 avisos, 6 sugerencias

| Línea | Tipo | Regla | Código |
| ---: | --- | --- | --- |
| 25 | Aviso | PSAvoidUsingWriteHost | `Write-Host '   PowerShell está restringido en este equipo por política de la empresa: esta herramienta no se ejecuta aquí.' -ForegroundColor Red` |
| 47 | Aviso | PSAvoidUsingWriteHost | `Write-Host ''` |
| 48 | Aviso | PSAvoidUsingWriteHost | `Write-Host "  $linea" -ForegroundColor DarkCyan` |
| 49 | Aviso | PSAvoidUsingWriteHost | `Write-Host "   $texto" -ForegroundColor Cyan` |
| 50 | Aviso | PSAvoidUsingWriteHost | `Write-Host "  $linea" -ForegroundColor DarkCyan` |
| 55 | Aviso | PSAvoidUsingWriteHost | `Write-Host ''` |
| 56 | Aviso | PSAvoidUsingWriteHost | `Write-Host "   $texto" -ForegroundColor Cyan` |
| 57 | Aviso | PSAvoidUsingWriteHost | `Write-Host ('   ' + '─' * 58) -ForegroundColor DarkGray` |
| 62 | Aviso | PSAvoidUsingWriteHost | `Write-Host ('   {0,-32} ' -f $nombre) -NoNewline` |
| 63 | Aviso | PSAvoidUsingWriteHost | `Write-Host $resultado -ForegroundColor $Colores[$tipo]` |
| 70 | Aviso | PSAvoidUsingWriteHost | `Write-Host ('   {0,-10}' -f $nombre) -NoNewline` |
| 71 | Aviso | PSAvoidUsingWriteHost | `Write-Host ('█' * $llenos) -ForegroundColor $Colores[$tipo] -NoNewline` |
| 72 | Aviso | PSAvoidUsingWriteHost | `Write-Host ('░' * (30 - $llenos)) -ForegroundColor DarkGray -NoNewline` |
| 73 | Aviso | PSAvoidUsingWriteHost | `Write-Host (' {0,3:N0} %   {1}' -f $pct, $detalle)` |
| 83 | Aviso | PSUseSingularNouns | `Get-SessionPrograms` |
| 100 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Bar $momento (100 * $usadaKB / $os.TotalVisibleMemorySize) ('{0:N1} GB de {1:N1} GB en uso' -f ($usadaKB / 1MB), ($os.TotalVisibleMemorySize / 1MB))` |
| 106 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'Procesos limpiados' $limpiados.Count 'ok'` |
| 108 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'Sin permiso' "$sinPermiso (abiertos como administrador)" 'info'` |
| 122 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line "  $($_.Nombre)" ('{0:N0} MB  (de {1:N0} a {2:N0} MB)' -f $_.Solto, $_.Antes, $_.Ahora) 'ok'` |
| 127 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'RAM liberada' ('{0:N0} MB' -f $liberada) 'ok'` |
| 128 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'RAM liberada' 'poca: tus programas ya usaban poca memoria' 'info'` |

## Monitor-Memoria.ps1: 9 avisos, 2 sugerencias

| Línea | Tipo | Regla | Código |
| ---: | --- | --- | --- |
| 25 | Aviso | PSAvoidUsingWriteHost | `Write-Host '   PowerShell está restringido en este equipo por política de la empresa: esta herramienta no se ejecuta aquí.' -ForegroundColor Red` |
| 74 | Aviso | PSAvoidUsingWriteHost | `Write-Host ''` |
| 75 | Aviso | PSAvoidUsingWriteHost | `Write-Host "  $linea" -ForegroundColor DarkCyan` |
| 76 | Aviso | PSAvoidUsingWriteHost | `Write-Host "   $texto" -ForegroundColor Cyan` |
| 77 | Aviso | PSAvoidUsingWriteHost | `Write-Host "  $linea" -ForegroundColor DarkCyan` |
| 82 | Aviso | PSAvoidUsingWriteHost | `Write-Host ('   {0,-32} ' -f $nombre) -NoNewline` |
| 83 | Aviso | PSAvoidUsingWriteHost | `Write-Host $resultado -ForegroundColor $Colores[$tipo]` |
| 152 | Aviso | PSAvoidUsingEmptyCatchBlock | `catch {}` |
| 163 | Aviso | PSUseShouldProcessForStateChangingFunctions | `Update-Icon` |
| 227 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'Estado' 'activo: mira el ícono junto al reloj' 'ok'` |
| 230 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'Esta ventana' 'déjala minimizada; si la cierras, el monitor se cierra' 'info'` |

## Optimizar-Internet.ps1: 22 avisos, 23 sugerencias

| Línea | Tipo | Regla | Código |
| ---: | --- | --- | --- |
| 25 | Aviso | PSAvoidUsingWriteHost | `Write-Host '   PowerShell está restringido en este equipo por política de la empresa: esta herramienta no se ejecuta aquí.' -ForegroundColor Red` |
| 65 | Aviso | PSAvoidUsingWriteHost | `Write-Host ''` |
| 66 | Aviso | PSAvoidUsingWriteHost | `Write-Host "  $linea" -ForegroundColor DarkCyan` |
| 67 | Aviso | PSAvoidUsingWriteHost | `Write-Host "   $texto" -ForegroundColor Cyan` |
| 68 | Aviso | PSAvoidUsingWriteHost | `Write-Host "  $linea" -ForegroundColor DarkCyan` |
| 73 | Aviso | PSAvoidUsingWriteHost | `Write-Host ''` |
| 74 | Aviso | PSAvoidUsingWriteHost | `Write-Host "   $texto" -ForegroundColor Cyan` |
| 75 | Aviso | PSAvoidUsingWriteHost | `Write-Host ('   ' + '─' * 58) -ForegroundColor DarkGray` |
| 80 | Aviso | PSAvoidUsingWriteHost | `Write-Host ('   {0,-32} ' -f $nombre) -NoNewline` |
| 81 | Aviso | PSAvoidUsingWriteHost | `Write-Host $resultado -ForegroundColor $Colores[$tipo]` |
| 92 | Aviso | PSUseSingularNouns | `Get-PhysicalAdapters` |
| 108 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line $nombre "$destino no responde (algunos equipos bloquean el ping)" 'aviso'` |
| 113 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line $nombre ('{0}: {1} de 4 respuestas, {2:N0} ms' -f $destino, $respuestas.Count, $promedio) $tipo` |
| 117 | Aviso | PSUseSingularNouns | `Invoke-CmdLines` |
| 123 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line $nombre 'OK' 'ok'` |
| 124 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line $nombre ('falló: ' + ($fallidos -join ' \| ')) 'mal'` |
| 129 | Aviso | PSUseShouldProcessForStateChangingFunctions | `Update-IP` |
| 131 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line "Renovar IP: $($adaptador.Name)" 'OK' 'ok'` |
| 132 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line "Renovar IP: $($adaptador.Name)" 'no se renovó (puede tener IP fija)' 'aviso'` |
| 139 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line $adaptador.Name "$($adaptador.LinkSpeed) (si tu plan es más rápido, cambia el cable a Cat 5e o más, o el puerto)" 'aviso'` |
| 164 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line "  $nombre" $valor $tipo` |
| 174 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line $nombre 'en ejecución' 'ok'` |
| 175 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line $nombre "$estado (como admin se intenta iniciar)" 'mal'` |
| 181 | Sugerencia | PSAvoidUsingPositionalParameters | `Test-Ping 'Ping al router' $router $MsRouter $MsRouterMalo` |
| 185 | Sugerencia | PSAvoidUsingPositionalParameters | `Test-Ping 'Ping a internet' $ServidorInternet $MsInternet $MsInternetMalo` |
| 191 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'Windows ve internet' ('sí, por ' + ($conInternet.InterfaceAlias -join ', ')) 'ok'` |
| 192 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'Windows ve internet' 'no: hay red, pero no salida a internet' 'mal'` |
| 195 | Aviso | PSUseSingularNouns | `Test-Dns` |
| 198 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'DNS' ('responde ({0:N0} ms)' -f $reloj.Elapsed.TotalMilliseconds) 'ok'` |
| 199 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'DNS' 'no responde' 'mal'` |
| 217 | Aviso | PSUseSingularNouns | `Set-TcpTweaks` |
| 217 | Aviso | PSUseShouldProcessForStateChangingFunctions | `Set-TcpTweaks` |
| 227 | Aviso | PSUseShouldProcessForStateChangingFunctions | `Set-StaticDns` |
| 227 | Aviso | PSUseSingularNouns | `Set-StaticDns` |
| 241 | Aviso | PSUseShouldProcessForStateChangingFunctions | `Reset-Firewall` |
| 245 | Aviso | PSUseShouldProcessForStateChangingFunctions | `Reset-IP` |
| 249 | Aviso | PSUseShouldProcessForStateChangingFunctions | `Reset-Winsock` |
| 253 | Aviso | PSUseShouldProcessForStateChangingFunctions | `Reset-Proxy` |
| 265 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'Modo' 'administrador: diagnóstico + mantenimiento de red' 'ok'` |
| 266 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'Modo' 'normal: renovar IP y diagnóstico (el mantenimiento pide admin)' 'info'` |
| 268 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'Conexión' 'no hay cable ni Wi-Fi conectado' 'mal'` |
| 270 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'VPN conectada' $vpn[0].InterfaceDescription 'info'` |
| 278 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'Renovar IP' 'se salta para no cortar la VPN' 'info'` |
| 308 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'Ping a internet' 'se salta con VPN' 'info'` |
| 313 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'Reparación profunda' 'reinicia el PC para terminarla' 'aviso'` |

## Optimizar-PC.ps1: 28 avisos, 33 sugerencias

| Línea | Tipo | Regla | Código |
| ---: | --- | --- | --- |
| 25 | Aviso | PSAvoidUsingWriteHost | `Write-Host '   PowerShell está restringido en este equipo por política de la empresa: esta herramienta no se ejecuta aquí.' -ForegroundColor Red` |
| 49 | Aviso | PSAvoidUsingWriteHost | `Write-Host ''` |
| 50 | Aviso | PSAvoidUsingWriteHost | `Write-Host "  $linea" -ForegroundColor DarkCyan` |
| 51 | Aviso | PSAvoidUsingWriteHost | `Write-Host "   $texto" -ForegroundColor Cyan` |
| 52 | Aviso | PSAvoidUsingWriteHost | `Write-Host "  $linea" -ForegroundColor DarkCyan` |
| 57 | Aviso | PSAvoidUsingWriteHost | `Write-Host ''` |
| 58 | Aviso | PSAvoidUsingWriteHost | `Write-Host "   $texto" -ForegroundColor Cyan` |
| 59 | Aviso | PSAvoidUsingWriteHost | `Write-Host ('   ' + '─' * 58) -ForegroundColor DarkGray` |
| 64 | Aviso | PSAvoidUsingWriteHost | `Write-Host ('   {0,-32} ' -f $nombre) -NoNewline` |
| 65 | Aviso | PSAvoidUsingWriteHost | `Write-Host $resultado -ForegroundColor $Colores[$tipo]` |
| 72 | Aviso | PSAvoidUsingWriteHost | `Write-Host ('   {0,-10}' -f $nombre) -NoNewline` |
| 73 | Aviso | PSAvoidUsingWriteHost | `Write-Host ('█' * $llenos) -ForegroundColor $Colores[$tipo] -NoNewline` |
| 74 | Aviso | PSAvoidUsingWriteHost | `Write-Host ('░' * (30 - $llenos)) -ForegroundColor DarkGray -NoNewline` |
| 75 | Aviso | PSAvoidUsingWriteHost | `Write-Host (' {0,3:N0} %   {1}' -f $pct, $detalle)` |
| 82 | Aviso | PSUseSingularNouns | `Remove-OldFiles` |
| 82 | Aviso | PSUseShouldProcessForStateChangingFunctions | `Remove-OldFiles` |
| 103 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line $nombre $texto $(if ($archivos) { 'ok' } else { 'info' })` |
| 108 | Aviso | PSUseSingularNouns | `Remove-EmptyFolders` |
| 108 | Aviso | PSUseShouldProcessForStateChangingFunctions | `Remove-EmptyFolders` |
| 111 | Aviso | PSAvoidUsingEmptyCatchBlock | `catch {}` |
| 115 | Aviso | PSUseShouldProcessForStateChangingFunctions | `Remove-CacheIfClosed` |
| 116 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line $nombre 'no instalado' 'info'` |
| 117 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line $nombre 'se salta: el programa está abierto' 'aviso'` |
| 123 | Aviso | PSUseSingularNouns | `Get-ChromiumCaches` |
| 129 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line $nombre 'ejecutando...' 'info'` |
| 131 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line $nombre 'OK' 'ok'` |
| 132 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line $nombre "terminó con código $($proceso.ExitCode)" 'mal'` |
| 168 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Bar "Disco $Unidad" (100 * $disco.Used / $total) ('{0:N1} GB libres de {1:N1} GB' -f ($disco.Free / 1GB), ($total / 1GB))` |
| 175 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'TRIM (discos SSD)' 'no se pudo consultar' 'info'` |
| 176 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'TRIM (discos SSD)' 'activado' 'ok'` |
| 177 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'TRIM (discos SSD)' 'desactivado: actívalo como admin con "fsutil behavior set DisableDeleteNotify 0"' 'aviso'` |
| 182 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'Días sin reiniciar' "$dias (reinicia con Inicio > Reiniciar)" 'aviso'` |
| 183 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'Días sin reiniciar' $dias 'ok'` |
| 188 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'Actualizaciones' 'esperando un reinicio' 'aviso'` |
| 190 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'Actualizaciones' 'sin reinicio pendiente' 'ok'` |
| 195 | Aviso | PSUseSingularNouns | `Show-StartupPrograms` |
| 205 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'Arrancan con Windows' ('{0} programas habilitados' -f $programas.Count) $tipo` |
| 211 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'Archivos borrados' ('{0} ({1:N1} MB)' -f $script:TotalArchivos, ($script:TotalBytes / 1MB)) 'ok'` |
| 212 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line "Espacio ganado en $Unidad" ('{0:N0} MB' -f [math]::Max(0, (Get-FreeSpaceMB) - $libreAntes)) 'ok'` |
| 219 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'Papelera' 'ya estaba vacía' 'info'` |
| 222 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'Papelera' "$elementos elementos vaciados" 'ok'` |
| 224 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'Papelera' 'no se vació (respondiste N)' 'info'` |
| 229 | Sugerencia | PSAvoidUsingPositionalParameters | `Remove-OldFiles 'Temporales (%TEMP%)' $env:TEMP $HorasMinimas` |
| 233 | Sugerencia | PSAvoidUsingPositionalParameters | `Remove-OldFiles 'Caché de internet (Windows)' "$Local\Microsoft\Windows\INetCache" $HorasMinimas` |
| 237 | Sugerencia | PSAvoidUsingPositionalParameters | `Remove-CacheIfClosed 'Caché de Chrome' 'chrome' (Get-ChromiumCaches "$Local\Google\Chrome\User Data")` |
| 241 | Sugerencia | PSAvoidUsingPositionalParameters | `Remove-CacheIfClosed 'Caché de Edge' 'msedge' (Get-ChromiumCaches "$Local\Microsoft\Edge\User Data")` |
| 245 | Sugerencia | PSAvoidUsingPositionalParameters | `Remove-CacheIfClosed 'Caché de Brave' 'brave' (Get-ChromiumCaches "$Local\BraveSoftware\Brave-Browser\User Data")` |
| 249 | Sugerencia | PSAvoidUsingPositionalParameters | `Remove-CacheIfClosed 'Caché de Firefox' 'firefox' "$Local\Mozilla\Firefox\Profiles\*\cache2"` |
| 253 | Sugerencia | PSAvoidUsingPositionalParameters | `Remove-CacheIfClosed 'Caché de Teams' 'ms-teams' "$Local\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams"` |
| 257 | Aviso | PSUseSingularNouns | `Clear-Thumbnails` |
| 264 | Sugerencia | PSAvoidUsingPositionalParameters | `Invoke-Tool 'Liberador de espacio' 'cleanmgr.exe' '/sagerun:1'` |
| 271 | Sugerencia | PSAvoidUsingPositionalParameters | `Remove-OldFiles 'Temporales de Windows' "$env:WINDIR\Temp" $HorasMinimas` |
| 280 | Aviso | PSUseSingularNouns | `Clear-ErrorReports` |
| 290 | Aviso | PSUseSingularNouns | `Clear-WindowsCookies` |
| 295 | Aviso | PSUseSingularNouns | `Clear-RecentFiles` |
| 301 | Aviso | PSUseSingularNouns | `Clear-WindowsComponents` |
| 302 | Sugerencia | PSAvoidUsingPositionalParameters | `Invoke-Tool 'DISM (WinSxS)' 'Dism.exe' '/Online /Cleanup-Image /StartComponentCleanup'` |
| 306 | Aviso | PSUseSingularNouns | `Optimize-Disks` |
| 307 | Sugerencia | PSAvoidUsingPositionalParameters | `Invoke-Tool 'Optimizar discos' 'defrag.exe' '/C /O'` |
| 317 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'Modo' 'administrador: limpieza + mantenimiento' 'ok'` |
| 318 | Sugerencia | PSAvoidUsingPositionalParameters | `Write-Line 'Modo' 'normal: solo limpieza (el mantenimiento pide admin)' 'info'` |
