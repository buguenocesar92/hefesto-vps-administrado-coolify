# config/

Configuración de operación del **kit de Hefesto**, no de Coolify.

Coolify no se configura con archivos: se configura desde el panel y guarda todo
en su propia base de datos y en `/data/coolify/source/.env`. Por eso esta
carpeta **no contiene** archivos de configuración de Coolify.

## Qué hay aquí

| Archivo | Qué hace |
|---|---|
| `coolify-backup.service` | Unidad systemd que ejecuta `scripts/backup-coolify.sh` |
| `coolify-backup.timer` | Programa esa ejecución una vez al día |

## Por qué un respaldo del kit y no solo el de Coolify

Son respaldos distintos y complementarios:

- El respaldo nativo de Coolify (panel → `Settings > Backup`) guarda **la base
  de datos**: proyectos, recursos, ajustes e historial de despliegues.
- El respaldo de este kit guarda **la base de datos + `/data/coolify` completo**,
  lo que incluye `source/.env` (con el `APP_KEY`) y `ssh/keys/`.

El `APP_KEY` cifra las credenciales guardadas en la base: sin él, el respaldo
de la base no sirve para recuperar la instancia. El respaldo nativo de Coolify
no lo incluye.

## Antes de activar esto

1. Copia el kit al servidor: `sudo cp -r <kit> /opt/hefesto/coolify-vps-gestionado`
2. `sudo chmod +x /opt/hefesto/coolify-vps-gestionado/scripts/*.sh`
3. Copia las unidades: `sudo cp config/*.service config/*.timer /etc/systemd/system/`
4. `sudo systemctl daemon-reload`
5. `sudo systemctl enable --now coolify-backup.timer`
6. **Pruébalo una vez a mano antes de dejarlo programado:**
   ```bash
   sudo systemctl start coolify-backup.service
   sudo journalctl -u coolify-backup -n 50
   ls -la /data/backups/coolify/
   ```
7. Verifica el respaldo con `sha256sum -c` desde dentro de la carpeta.

Un respaldo que nunca se restauró en un servidor de prueba **no es un respaldo**.
Prueba una restauración completa antes de prometerlo al cliente.

## Estado

**No instalado ni ejecutado en un servidor real.** El kit está en estado
`kit preparado`.
