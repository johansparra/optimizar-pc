# Logs en Optimizar-PC — diseño corto

## Para qué

Que cada ejecución de Optimizar-PC deje un archivo de registro con más detalle que la pantalla. Así, si algo falla en el portátil del banco (donde no hay Claude Code), se copia el `.log` al PC personal y se ve qué pasó y en qué función.

## Qué hace

- **Dónde**: carpeta `log\` al lado del `.ps1`. Un archivo por ejecución: `op-pc-yyyy-MM-dd_HH-mm-ss.log`.
- **Rotación** (al iniciar): se borran los de antes de ayer; de cada día quedan máximo 3, contando el nuevo. Nunca más de 6 archivos.
- **Tamaño máximo**: 10 MB por archivo. En INFO un archivo pesa unos KB; solo DEBUG puede crecer. Al llegar a 10 MB se dejan de escribir las líneas DEBUG (queda una línea WARN que lo dice) y siguen las INFO/WARN/ERROR, que son pocas, para que el resumen y los errores no se pierdan. Peor caso en disco: 6 × 10 MB, solo si se usa DEBUG.
- **Memoria**: cada línea se escribe directo al disco; el log no se acumula en RAM.
- **Niveles**: DEBUG < INFO < WARN < ERROR. Se elige con `$NivelLog` en la sección CONFIGURACIÓN; por defecto `INFO`.
- **Formato** de cada línea:
  `2026-11-22 21:05:33.120 [INFO ] Clear-Temp>Remove-OldFile | Temporales (%TEMP%): 120 archivos, 45.3 MB`
  La columna del medio es la cadena de funciones que llevó a esa línea, sin las de pantalla y log (`Write-*`).
- **Encabezado**: versión del script, modo (admin o no), nivel, versión de Windows y de PowerShell.
- **Qué se registra**:
  - INFO / WARN / ERROR: todo lo que sale en pantalla, según su color (verde y gris → INFO, amarillo → WARN, rojo → ERROR).
  - DEBUG: cada archivo borrado (ruta y tamaño); cada archivo que no se pudo borrar, con el motivo de Windows; carpetas que no se pudieron quitar; el comando exacto y el código de salida de DISM, sfc, defrag, etc.
  - DEBUG, al final: cada error de PowerShell de la ejecución (de `$Error`), con la función y el número de línea donde ocurrió. Va en DEBUG y no en ERROR porque los scripts ignoran a propósito cientos de errores inofensivos (temporales sin permiso, programas cerrados).
  - `Main` no va dentro de `try` (lo encontró la revisión): dentro de un `try`, un error que antes salía en rojo y dejaba seguir detiene todo el resto, y en el monitor abre la ventana de error de .NET.

## Decidido en la conversación

- Sin `log.xml`: el nivel es una variable en el `.ps1`.
- El bloque de log va **dentro de cada `.ps1`**, idéntico en los 4 scripts. Cada carpeta sigue funcionando sola al copiarla a mano. Lo único que cambia entre scripts está en CONFIGURACIÓN: `$NivelLog` y `$PrefijoLog` (`op-pc`, `op-net`, `limpiar-mem`, `monitor-mem`).
- Monitor-Memoria lleva log **solo a alto nivel**: inicio, cada limpieza, activar/desactivar la limpieza automática, errores y fin. Nunca cada lectura de la RAM.
- Sin pruebas automáticas (cambio del usuario al aprobar el plan): los comandos ya funcionan, solo se agregan logs.
- Descartado: un `Log.ps1` compartido (un archivo más que copiar al banco y un punto de falla más).

## No entra

Rotación por tamaño, un `.bat` aparte para DEBUG (se puede agregar después).

## Lo que no puede pasar

- Que el log impida la limpieza: si no puede crear la carpeta o el archivo, avisa en pantalla y el script sigue igual que hoy.
- Nada que llame la atención del antivirus: solo cmdlets y .NET normal (sin `Add-Type`).
- Nombres de archivos en INFO: solo en DEBUG, porque los temporales a veces son copias de documentos del banco.

## Decisiones de Claude (a revisar)

- "2 días" = hoy y ayer, por la fecha del nombre del archivo.
- Se agrega el nivel WARN (la pantalla ya tiene avisos amarillos).
- El archivo se escribe línea por línea (si se cierra la ventana a mitad, lo escrito queda).
- `log/` va al `.gitignore` para que las pruebas no se suban al repositorio.
- Versiones: Optimizar-PC 1.4.0, Optimizar-Internet 1.2.0, Limpiar-Memoria 1.1.0 y Monitor-Memoria 1.1.0, con su nota en CHANGELOG.md.
- La función se llama `Write-LogLine` (no `Write-Log`: PSScriptAnalyzer la marca porque PowerShell 6.1 trae un comando con ese nombre). La variable del archivo es `$script:ArchivoLog` (no `$Log`: en PowerShell `$log` y `$Log` son la misma variable).
- Riesgo conocido: en DEBUG, con miles de archivos de caché, el log puede pesar varios MB y la ejecución tardar unos segundos más.
