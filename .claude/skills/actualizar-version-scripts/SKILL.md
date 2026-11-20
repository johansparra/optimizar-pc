---
name: actualizar-version-scripts
description: Úsala cada vez que cambies un .ps1 de este repo (Limpiar-Memoria, Monitor-Memoria, Optimizar-Internet, Optimizar-PC) y antes de hacer commit de esos cambios. Sube la .VERSION, agrega la nota en .RELEASENOTES, mantiene .SYNOPSIS/.DESCRIPTION al día y valida con Test-PSScriptFileInfo y PSScriptAnalyzer (incluida la compatibilidad con PowerShell 5.1).
---

# Mantener al día el bloque PSScriptInfo

Cada `.ps1` empieza con dos bloques de comentarios:

1. `<#PSScriptInfo ... #>`: versión, GUID, autor, enlace del proyecto y notas de versión.
2. `<# .SYNOPSIS / .DESCRIPTION / .NOTES #>`: qué hace el script (lo muestra `Get-Help .\script.ps1`).

Son solo comentarios: no cambian lo que hace el script.

## Cuándo

En cada cambio a un `.ps1`, antes del commit. Si el cambio toca varios scripts, actualiza el bloque de cada uno. Si un cambio solo toca el README o un `.bat`, no hace falta.

## Pasos (por cada script cambiado)

1. **Sube `.VERSION`** (formato `mayor.menor.parche`):
   - **parche** (`1.0.0` → `1.0.1`): arreglo de un error, textos, comentarios o colores. El script hace lo mismo.
   - **menor** (`1.0.1` → `1.1.0`): algo nuevo o distinto que se nota al usarlo (una limpieza nueva, un dato nuevo en el reporte, otro orden en `Main`). Reinicia el parche a 0.
   - **mayor** (`1.1.0` → `2.0.0`): quitar algo que hacía, renombrar el `.ps1` o su `.bat`, o cualquier cambio que obligue a usarlo distinto. Reinicia menor y parche a 0.
2. **Agrega una línea en `.RELEASENOTES`**, debajo de `.RELEASENOTES` y encima de las anteriores:
   `x.y.z (AAAA-MM-DD): qué cambió, en una frase en español.`
   Nunca borres las líneas anteriores: son el historial.
3. **Si cambió lo que hace el script**, actualiza `.SYNOPSIS` y `.DESCRIPTION`. Si cambió el orden de las secciones, actualiza la línea "Orden del archivo" en `.NOTES`.
4. **No toques** `.GUID` (es la identidad del script y nunca cambia) ni `.AUTHOR`. `.PROJECTURI` solo cambia si el repositorio de GitHub cambia de nombre (eso es un **parche**).
5. **Valida** en PowerShell 7 (en PowerShell 5.1 no existe el comando). Cada script debe dar `True`:

   ```powershell
   Get-ChildItem -Recurse -Filter *.ps1 | Where-Object FullName -notmatch '\\RAMMap\\' |
       ForEach-Object { '{0}: {1}' -f $_.Name, (Test-PSScriptFileInfo $_.FullName) }
   ```

6. **Analiza el código** con PSScriptAnalyzer, también en PowerShell 7. Usa las reglas de [audit/PSScriptAnalyzerSettings.psd1](../../../audit/PSScriptAnalyzerSettings.psd1): todas las reglas normales y, además, avisa si algo solo existe en PowerShell 7 (los `.bat` abren los scripts con PowerShell 5.1). Desde la raíz del repo:

   ```powershell
   Get-ChildItem -Recurse -Filter *.ps1 | Where-Object FullName -notmatch '\\RAMMap\\' |
       ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Settings .\audit\PSScriptAnalyzerSettings.psd1 } |
       Format-Table ScriptName, Line, Severity, RuleName, Message -AutoSize -Wrap
   ```

   **No debe salir nada**: cualquier aviso se arregla antes del commit. Las costumbres que lo mantienen limpio:
   - En las llamadas a funciones del script, del 3.er argumento en adelante va con nombre: `Write-Line 'Modo' 'normal' -tipo 'info'`.
   - Nombres de función en singular (`Remove-OldFile`, no `Remove-OldFiles`).
   - Nada de `catch {}` vacío: si el error se ignora a propósito, deja `Write-Verbose` con el motivo.
   - `Write-Host` y la falta de `-WhatIf` ya están marcados como intencionales con `SuppressMessageAttribute` encima de `param()`. Solo agrega otra marca así si de verdad es a propósito, con su `Justification`, y explícala en [audit/PSScriptAnalyzer.md](../../../audit/PSScriptAnalyzer.md).

7. **Revisa la codificación**: cada `.ps1` debe seguir en UTF-8 **con BOM** y finales de línea CRLF. Sin BOM, PowerShell 5.1 de la laptop lee mal los acentos. En Git Bash:

   ```bash
   file */*.ps1   # debe decir "UTF-8 (with BOM) text, with CRLF line terminators"
   ```

8. **En el mensaje de commit**, nombra la versión nueva de cada script (por ejemplo `Optimizar-PC 1.1.0`).

## No hagas

- **No uses `Update-PSScriptFileInfo`.** Quita el BOM del archivo, reemplaza las notas de versión anteriores en vez de agregar y llena el bloque de campos vacíos. Edita el bloque a mano.
- **No instales PSResourceGet ni PSScriptAnalyzer, ni valides o analices en la laptop del banco.** La validación se hace solo en el PC personal.
- **No subas la versión de un script que no cambió**, aunque se cambien otros en el mismo commit.
