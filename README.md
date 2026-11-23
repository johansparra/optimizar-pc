# optimizar-pc

Herramientas para Windows pensadas para un PC corporativo (con VPN Cisco y Zscaler). Cada una está en su carpeta, funciona sola y se abre con doble clic en su `.bat`.

- **Doble clic:** no necesita administrador. Es lo que se usa en el PC de la empresa.
- **Clic derecho en el `.bat` > Ejecutar como administrador:** algunas hacen además un mantenimiento más profundo. Pensado para tu PC personal.

| Carpeta | Doble clic (sin administrador) | Como administrador, además |
| --- | --- | --- |
| `Limpiar-Memoria` | Libera la RAM que no usan los programas de la lista (solo los de tu sesión). Muestra antes y después, cuánto soltó cada programa y qué usa más RAM ahora. | — |
| `Optimizar-PC` | Borra temporales de más de 24 h, cachés de Chrome, Edge, Brave, Firefox y Teams (solo si están cerrados) y miniaturas. Vacía la Papelera y corre el Liberador de espacio. Dice cuántos archivos y MB borró y cuántos estaban en uso. Revisa disco, salud de los discos (SMART), TRIM del SSD, salud de la batería (en laptops), plan de energía (avisa si es Economizador), días sin reiniciar, actualizaciones y programas de inicio habilitados. | Marca todas las opciones del Liberador menos Descargas. Temporales de Windows, DISM, activar TRIM, optimizar discos y, si respondes **S** al inicio, reparar Windows (DISM y sfc). Solo para PC personal: informes de errores, historial, cookies y archivos recientes. |
| `Optimizar-Internet` | Revisa los servicios DHCP y DNS y renueva la IP (solo si no hay VPN). Muestra IP, router, DNS y datos del Wi-Fi. Hace ping al router y a internet (sin VPN) y prueba el DNS. | Inicia los servicios DHCP y DNS si están apagados, aplica los ajustes TCP, desactiva Teredo, fija el DNS y al final vacía las cachés DNS, NetBIOS y ARP. Si respondes **S**, hace la reparación profunda (firewall, IP, Winsock y proxy) y pide reiniciar. |
| `Monitor-Memoria` | Ícono junto al reloj con el % de RAM en uso. Doble clic: liberar memoria. Clic derecho: limpieza automática al pasar de 85 %, Administrador de tareas y Salir. | — |

## Qué no hacen, a propósito

- Para lo normal no piden administrador. No instalan nada, no descargan nada y no compilan código.
- No usan `-ExecutionPolicy Bypass` ni ventanas ocultas. El monitor deja una ventana minimizada visible en la barra de tareas.
- No tocan procesos de Windows, antivirus, VPN ni Zscaler: la memoria solo se libera en los programas de la lista `$Programas`.
- Con la VPN conectada no renuevan la IP, no hacen ping a servidores externos y no ofrecen la reparación profunda.
- Sin administrador no borran informes de errores, historial ni nada fuera de las carpetas temporales y cachés de tu usuario. Eso solo pasa como administrador, en tu PC personal.

## Antes de usarlas en el PC de la empresa

Las herramientas ya revisan solas si la empresa restringe PowerShell. Si es así, muestran un aviso en rojo y no hacen nada. Para comprobarlo antes, abre PowerShell normal (sin admin) y ejecuta estas dos líneas:

```powershell
$ExecutionContext.SessionState.LanguageMode
Get-ExecutionPolicy -List
```

- `FullLanguage` y ninguna política `AllSigned` o `Restricted` en `MachinePolicy` / `UserPolicy`: las herramientas pueden funcionar.
- `ConstrainedLanguage`, o `AllSigned` / `Restricted` en `MachinePolicy` / `UserPolicy`: la empresa bloquea los scripts. No lo fuerces; pregúntale a TI.

## Cómo están hechos los `.ps1`

Todos siguen el mismo orden, de arriba abajo:

0. **Bloques de información** (solo comentarios): versión, autor y nota de la versión actual (`<#PSScriptInfo`), y la ayuda que muestra `Get-Help .\Optimizar-PC\Optimizar-PC.ps1`. El historial de versiones de los 4 scripts está en [CHANGELOG.md](CHANGELOG.md). Al cambiar un script se sube su versión y se anota qué cambió; la skill `actualizar-version-scripts` (en `.claude/skills`) lo hace con Claude Code.
1. **CHEQUEO INICIAL:** se detiene si PowerShell está restringido.
2. **CONFIGURACIÓN:** lo que puedes cambiar sin tocar el resto. Por ejemplo, la lista `$Programas`, las horas mínimas de los temporales, los límites de los pings, tus ajustes TCP y DNS o el nivel del log (`$NivelLog`).
3. **LOG:** escribe el log de cada ejecución (`Start-Log`, `Write-LogLine`, `Stop-Log`). Lo que sale en pantalla llega solo al log a través de la VISTA.
4. **VISTA:** todo lo visual (títulos, colores y barras). Los demás métodos solo dicen el tipo de resultado (`ok`, `aviso`, `mal` o `info`), y la VISTA decide el color.
5. **MÉTODOS REUTILIZABLES:** piezas que usan varias tareas, como `Remove-OldFile`.
6. **Tareas:** un método por tarea (`Clear-Temp`, `Test-DnsResolution`...). Las de administrador están en la sección MANTENIMIENTO.
7. **MAIN:** al final; llama a las tareas en orden.

Los nombres de los métodos están en inglés, con los verbos oficiales de PowerShell (`Get-`, `Show-`, `Clear-`, `Test-`...) y en singular, para que VS Code y PSScriptAnalyzer no los marquen con avisos. Comentarios y mensajes siguen en español. Para agregar una limpieza, escribe un método nuevo de una línea con `Remove-OldFile` y llámalo desde `Main`.

Tres cosas que hay que mantener iguales a mano, porque cada carpeta funciona sola:

- Los métodos de **VISTA** son idénticos en los 4 archivos: si cambias uno, cópialo igual en los demás.
- La sección **LOG** también es idéntica en los 4: lo único que cambia entre scripts está en CONFIGURACIÓN (`$NivelLog` y `$PrefijoLog`).
- La lista **`$Programas`** está en `Limpiar-Memoria` y en `Monitor-Memoria`: si agregas o quitas un programa, hazlo en las dos.

## Notas

- **Descarga desde GitHub:** antes de extraer el ZIP, clic derecho > Propiedades > Desbloquear. Si no, Windows no deja ejecutar los `.ps1`.
- **Copiar al PC de la empresa:** basta con copiar la carpeta de la herramienta que necesites. La carpeta `.claude` es solo para Claude Code y no hace falta.
- **Logs:** cada herramienta deja un `.log` por ejecución en la carpeta `log` junto a su `.ps1` (por ejemplo `Optimizar-PC\log\op-pc-2026-11-22_21-05-33.log`). Cada línea dice la hora, el nivel, la función donde pasó y el mensaje. Se guardan los de hoy y ayer, máximo 3 por día y 10 MB por archivo, así que ocupan pocos KB. Si algo falla en el PC de la empresa, copia ese archivo y revísalo aquí.
  - Para ver todo el detalle, cambia `$NivelLog` a `'DEBUG'` en la CONFIGURACIÓN del `.ps1`. Úsalo solo mientras revisas una falla: en DEBUG salen nombres de archivos, comandos y, al final, cada error de PowerShell con la función y la línea donde pasó. El log pesa más. Luego vuelve a `'INFO'`.
  - El monitor solo anota el inicio, cada limpieza, la limpieza automática al activarla o desactivarla, los errores y el fin. Nunca anota cada lectura. El `Fin` solo queda si lo cierras con clic derecho > Salir; si cierras su ventana con la X, Windows lo corta antes (lo anotado hasta ahí no se pierde).
  - Si no se puede crear la carpeta `log`, la herramienta lo avisa en amarillo y funciona igual.
- **Monitor sin ícono visible:** está en la flecha `^` junto al reloj. Arrástralo a la barra de tareas una vez.
- **Liberador de espacio:** como administrador, el script marca todas sus opciones menos **Descargas** (para no borrar tus archivos descargados) y lo ejecuta. Sin administrador usa las opciones ya guardadas con `cleanmgr /sageset:1`; si nunca se configuraron, no hace nada. Entre las opciones marcadas están "Instalaciones anteriores de Windows" (después no puedes volver a la versión anterior), "Archivos de instalación ESD" ("Restablecer este PC" tendría que descargar Windows) y los drivers viejos.
- **Ajustes de red como administrador** (solo PC personal):
  - "Restablecer firewall" borra las reglas que tus programas agregaron al firewall de Windows.
  - Desactivar Teredo deja sin chat de grupo a la app Xbox.
  - El DNS se fija en el adaptador `$AdaptadorDns` (por defecto `Ethernet`).
