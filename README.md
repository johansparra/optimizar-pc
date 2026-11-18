# Memory

Herramientas para Windows que **no necesitan administrador**, pensadas para un PC corporativo (con VPN Cisco y Zscaler). Cada una está en su carpeta y se abre con doble clic en su `.bat`.

| Carpeta | Qué hace |
|---|---|
| `Limpiar-Memoria` | Libera RAM de navegadores, Office, Teams y otros programas comunes, y muestra cuánto liberó. |
| `Optimizar-PC` | Borra temporales y cachés de tu usuario, ofrece vaciar la Papelera y revisa el equipo (disco, reinicio, programas de inicio). |
| `Optimizar-Internet` | Renueva la IP (solo si no hay VPN conectada) y revisa Wi-Fi, router, internet y DNS, con recomendaciones. |
| `Monitor-Memoria` | Ícono junto al reloj con el % de RAM en uso. Doble clic libera memoria; clic derecho > Salir para cerrarlo. |

## Qué no hacen, a propósito

- No piden administrador, no instalan nada, no descargan nada y no compilan código.
- No usan `-ExecutionPolicy Bypass` ni ventanas ocultas. El monitor deja una ventana minimizada visible en la barra de tareas.
- No tocan procesos de Windows, antivirus, VPN ni Zscaler: la memoria solo se libera en los programas de la lista `$Programas`.
- Con la VPN conectada no renuevan la IP ni hacen ping a servidores externos.
- No borran informes de errores, registros ni nada fuera de las carpetas temporales y cachés de tu usuario.

## Antes de usarlas en el PC de la empresa

Abre PowerShell normal (sin admin) y ejecuta estas dos líneas:

```powershell
$ExecutionContext.SessionState.LanguageMode
Get-ExecutionPolicy -List
```

- `FullLanguage` y ninguna política `AllSigned` o `Restricted` en `MachinePolicy` / `UserPolicy`: las herramientas pueden funcionar.
- `ConstrainedLanguage`, o `AllSigned` / `Restricted` en `MachinePolicy` / `UserPolicy`: la empresa bloquea los scripts. No lo fuerces; pregúntale a TI.

## Notas

- **Descarga desde GitHub:** antes de extraer el ZIP, clic derecho > Propiedades > Desbloquear. Si no, Windows no deja ejecutar los `.ps1`.
- **Monitor sin ícono visible:** está en la flecha `^` junto al reloj. Arrástralo a la barra de tareas una vez.
- **Modo prueba de Optimizar-PC** (calcula sin borrar): `powershell -ExecutionPolicy RemoteSigned -File .\Optimizar-PC\Optimizar-PC.ps1 -Simular`
