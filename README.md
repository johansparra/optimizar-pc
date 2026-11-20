# optimizar-pc

Herramientas para Windows pensadas para un PC corporativo (con VPN Cisco y Zscaler). Cada una está en su carpeta, funciona sola y se abre con doble clic en su `.bat`.

- **Doble clic:** no necesita administrador. Es lo que se usa en el PC de la empresa.
- **Clic derecho en el `.bat` > Ejecutar como administrador:** algunas hacen además un mantenimiento más profundo. Pensado para tu PC personal.

| Carpeta | Doble clic (sin administrador) | Como administrador, además |
| --- | --- | --- |
| `Limpiar-Memoria` | Libera la RAM que no usan los programas de la lista (solo los de tu sesión). Muestra antes y después, cuánto soltó cada programa y qué usa más RAM ahora. | — |
| `Optimizar-PC` | Borra temporales de más de 24 h, cachés de Chrome, Edge, Brave, Firefox y Teams (solo si están cerrados) y miniaturas. Ofrece vaciar la Papelera y corre el Liberador de espacio. Dice cuántos archivos y MB borró y cuántos estaban en uso. Revisa disco, TRIM del SSD, días sin reiniciar, actualizaciones y programas de inicio habilitados. | Temporales de Windows, DISM y optimizar discos. Solo para PC personal: informes de errores, historial, cookies y archivos recientes. |
| `Optimizar-Internet` | Renueva la IP (solo si no hay VPN). Muestra IP, router, DNS y datos del Wi-Fi. Revisa los servicios DHCP y DNS, hace ping al router y a internet (sin VPN) y prueba el DNS. | Vacía las cachés DNS, NetBIOS y ARP, aplica los ajustes TCP, desactiva Teredo y fija el DNS. Si respondes **S**, hace la reparación profunda (firewall, IP, Winsock y proxy) y pide reiniciar. |
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

0. **Bloques de información** (solo comentarios): versión, autor y notas de versión (`<#PSScriptInfo`), y la ayuda que muestra `Get-Help .\Optimizar-PC\Optimizar-PC.ps1`. Al cambiar un script se sube su versión y se anota qué cambió; la skill `actualizar-version-scripts` (en `.claude/skills`) lo hace con Claude Code.
1. **CHEQUEO INICIAL:** se detiene si PowerShell está restringido.
2. **CONFIGURACIÓN:** lo que puedes cambiar sin tocar el resto. Por ejemplo, la lista `$Programas`, las horas mínimas de los temporales, los límites de los pings o tus ajustes TCP y DNS.
3. **VISTA:** todo lo visual (títulos, colores y barras). Los demás métodos solo dicen el tipo de resultado (`ok`, `aviso`, `mal` o `info`), y la VISTA decide el color.
4. **MÉTODOS REUTILIZABLES:** piezas que usan varias tareas, como `Remove-OldFile`.
5. **Tareas:** un método por tarea (`Clear-Temp`, `Test-DnsResolution`...). Las de administrador están en la sección MANTENIMIENTO.
6. **MAIN:** al final; llama a las tareas en orden.

Los nombres de los métodos están en inglés, con los verbos oficiales de PowerShell (`Get-`, `Show-`, `Clear-`, `Test-`...) y en singular, para que VS Code y PSScriptAnalyzer no los marquen con avisos. Comentarios y mensajes siguen en español. Para agregar una limpieza, escribe un método nuevo de una línea con `Remove-OldFile` y llámalo desde `Main`.

Dos cosas que hay que mantener iguales a mano, porque cada carpeta funciona sola:

- Los métodos de **VISTA** son idénticos en los 4 archivos: si cambias uno, cópialo igual en los demás.
- La lista **`$Programas`** está en `Limpiar-Memoria` y en `Monitor-Memoria`: si agregas o quitas un programa, hazlo en las dos.

## Notas

- **Descarga desde GitHub:** antes de extraer el ZIP, clic derecho > Propiedades > Desbloquear. Si no, Windows no deja ejecutar los `.ps1`.
- **Copiar al PC de la empresa:** basta con copiar la carpeta de la herramienta que necesites. La carpeta `.claude` es solo para Claude Code y no hace falta.
- **Monitor sin ícono visible:** está en la flecha `^` junto al reloj. Arrástralo a la barra de tareas una vez.
- **Liberador de espacio:** usa las opciones guardadas con `cleanmgr /sageset:1`, que se configuran una vez como administrador. Si nunca se configuraron, no hace nada. Si entre esas opciones está la Papelera, la vacía aunque respondas **N** a la pregunta del script.
- **Ajustes de red como administrador** (solo PC personal):
  - "Restablecer firewall" borra las reglas que tus programas agregaron al firewall de Windows.
  - Desactivar Teredo deja sin chat de grupo a la app Xbox.
  - El DNS se fija en el adaptador `$AdaptadorDns` (por defecto `Ethernet`).
