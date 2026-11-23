# Historial de versiones

En el `.RELEASENOTES` de cada `.ps1` solo está la nota de su versión actual. Aquí está el historial completo de los 4 scripts, con lo más nuevo arriba.

## Limpiar-Memoria

- **1.1.1** (2026-11-22): en el log, la columna de la función ya no muestra comandos de Windows a mitad de camino (por ejemplo `Get-PhysicalDisk<Process>`), solo las funciones del script. El script hace lo mismo.
- **1.1.0** (2026-11-22): deja un log de cada ejecución en la carpeta log\, con la función donde pasó cada cosa. El nivel se elige en $NivelLog (INFO por defecto; DEBUG anota qué programas encontró y cuáles no se dejaron limpiar). Guarda los de hoy y ayer, máximo 3 por día y 10 MB por archivo.
- **1.0.2** (2026-11-19): sin avisos de PSScriptAnalyzer (argumentos con nombre, funciones en singular, Write-Host marcado como intencional). El script hace lo mismo.
- **1.0.1** (2026-11-19): enlace del proyecto actualizado al nuevo nombre del repositorio en GitHub (optimizar-pc).
- **1.0.0** (2026-11-19): primera versión con este bloque. Estructura por métodos, VISTA, chequeo de PowerShell restringido y bloque de administrador.

## Monitor-Memoria

- **1.1.2** (2026-11-22): el log ya no copia las 4 líneas de instrucciones de la ventana; empieza con el encabezado y solo anota eventos. El monitor hace lo mismo.
- **1.1.1** (2026-11-22): en el log, la columna de la función ya no muestra comandos de Windows a mitad de camino (por ejemplo `Get-PhysicalDisk<Process>`), solo las funciones del script. El script hace lo mismo.
- **1.1.0** (2026-11-22): deja un log en la carpeta log\ solo con lo importante: el inicio, cada limpieza (manual o automática) con lo que liberó, cuando se activa o desactiva la limpieza automática, los errores y el fin. Nunca anota cada lectura de la RAM.
- **1.0.2** (2026-11-19): sin avisos de PSScriptAnalyzer (argumentos con nombre, el catch vacío ahora deja nota, Write-Host y -WhatIf marcados como intencionales). El script hace lo mismo.
- **1.0.1** (2026-11-19): enlace del proyecto actualizado al nuevo nombre del repositorio en GitHub (optimizar-pc).
- **1.0.0** (2026-11-19): primera versión con este bloque. Estructura por métodos, VISTA, chequeo de PowerShell restringido y bloque de administrador.

## Optimizar-Internet

- **1.2.1** (2026-11-22): en el log, la columna de la función ya no muestra comandos de Windows a mitad de camino (por ejemplo `Get-PhysicalDisk<Process>`), solo las funciones del script. El script hace lo mismo.
- **1.2.0** (2026-11-22): deja un log de cada ejecución en la carpeta log\, con la función donde pasó cada cosa. El nivel se elige en $NivelLog (INFO por defecto; DEBUG anota los adaptadores, cada comando de red con su respuesta y lo que devolvió el DNS). Guarda los de hoy y ayer, máximo 3 por día y 10 MB por archivo.
- **1.1.1** (2026-11-22): renovar la IP ya no se queda colgado cuando el router no da IP (pasa al prender el PC): espera máximo 30 segundos, avisa en rojo y sigue con el diagnóstico.
- **1.1.0** (2026-11-20): los servicios DHCP y Cliente DNS se revisan (y como admin se inician) antes de renovar la IP, que los necesita. Como admin, las cachés se vacían después de los ajustes y el DNS fijo, no antes.
- **1.0.2** (2026-11-19): sin avisos de PSScriptAnalyzer (argumentos con nombre, funciones en singular, Write-Host y -WhatIf marcados como intencionales). El script hace lo mismo.
- **1.0.1** (2026-11-19): enlace del proyecto actualizado al nuevo nombre del repositorio en GitHub (optimizar-pc).
- **1.0.0** (2026-11-19): primera versión con este bloque. Estructura por métodos, VISTA, chequeo de PowerShell restringido y bloque de administrador.

## Optimizar-PC

- **1.4.1** (2026-11-22): en el log, la columna de la función ya no muestra comandos de Windows a mitad de camino (por ejemplo `Get-PhysicalDisk<Process>`), solo las funciones del script. El script hace lo mismo.
- **1.4.0** (2026-11-22): deja un log de cada ejecución en la carpeta log\, con la función donde pasó cada cosa. El nivel se elige en $NivelLog (INFO por defecto; DEBUG anota cada archivo borrado y el motivo de los que estaban en uso). Guarda los de hoy y ayer, máximo 3 por día y 10 MB por archivo.
- **1.3.0** (2026-11-21): la Papelera se vacía siempre, sin preguntar. Como administrador, marca en el Liberador de espacio todas las opciones menos Descargas antes de ejecutarlo, y la pregunta de reparar Windows pasa al inicio para que el resto corra sin detenerse.
- **1.2.0** (2026-11-20): la revisión del equipo muestra la salud de los discos (SMART) y, en laptops, de la batería. Como administrador, ofrece reparar Windows (DISM y sfc) con S/N. Arreglado: el Liberador de espacio (cleanmgr) dejaba el script colgado; ahora se espera con un tope de tiempo, continúa y muestra cuánto tardó y cuánto liberó.
- **1.1.0** (2026-11-20): como administrador también activa TRIM en los discos SSD, antes de optimizar los discos. Sin administrador, la revisión dice cómo activarlo.
- **1.0.2** (2026-11-19): sin avisos de PSScriptAnalyzer (argumentos con nombre, funciones en singular, el catch vacío ahora deja nota, Write-Host y -WhatIf marcados como intencionales). El script hace lo mismo.
- **1.0.1** (2026-11-19): enlace del proyecto actualizado al nuevo nombre del repositorio en GitHub (optimizar-pc).
- **1.0.0** (2026-11-19): primera versión con este bloque. Estructura por métodos, VISTA, chequeo de PowerShell restringido y bloque de administrador.
