# 03 — Variables de entorno y cómo obtenerlas

Este documento separa dos cosas que se confunden seguido:

1. **Las variables del panel de Coolify**, que el instalador oficial genera solo.
2. **Las variables del kit de Hefesto**, que controlan nuestros scripts.

---

## 1. Variables del panel (las genera el instalador, no las inventamos)

El instalador oficial crea `/data/coolify/source/.env`. Los nombres y el orden
están verificados leyendo <https://cdn.coollabs.io/coolify/install.sh> y la
plantilla `/.env.production` que descarga
(<https://cdn.coollabs.io/coolify/.env.production>).

| Variable | Qué es | Quién la genera | Qué pasa si la cambias a posteriori |
|---|---|---|---|
| `APP_KEY` | Llave con la que Laravel cifra los datos sensibles (credenciales guardadas, claves privadas) | `install.sh` | **Rompe la instancia**: los secretos ya guardados dejan de descifrarse. Es el valor más crítico del archivo |
| `APP_ID` / `APP_NAME` | Identidad de la aplicación | `install.sh` / plantilla | Bajo riesgo |
| `DB_USERNAME` | Usuario de la base interna | Plantilla (por defecto `coolify`) | Hay que ajustar `DB_PASSWORD` en el mismo cambio |
| `DB_PASSWORD` | Contraseña de la base interna | `install.sh` | Rompe la conexión del panel |
| `REDIS_PASSWORD` | Contraseña de la caché interna | `install.sh` | Rompe la conexión del panel |
| `PUSHER_APP_ID`, `PUSHER_APP_KEY`, `PUSHER_APP_SECRET` | Tiempo real (panel y terminal web) | `install.sh` | Rompe actualizaciones en vivo y terminal |
| `ROOT_USERNAME`, `ROOT_USER_EMAIL`, `ROOT_USER_PASSWORD` | Cuenta inicial del panel | `install.sh` o tus variables de entorno | Solo si la cuenta inicial aún no se ha creado |
| `REGISTRY_URL` | Registro de imágenes Docker (por defecto `docker.io`) | `install.sh` | Puede hacer que las actualizaciones no encuentren la imagen |
| `AUTOUPDATE` | Si se activa la actualización automática de Coolify | `install.sh` | Si está definido, la opción de frecuencia de actualización **desaparece** en el panel |
| `PUSHER_BACKEND_PORT` | Puerto del servicio de tiempo real (por defecto 6001) | `install.sh` | Debe coincidir con el puerto publicado |

### 1.1 Cómo leerlas sin exponerlas

```bash
# Ver los nombres de las variables, sin sus valores:
sudo grep -o '^[A-Z_]*=' /data/coolify/source/.env | tr -d '='

# Ver una en particular (úsalo solo cuando sea necesario):
sudo grep '^APP_KEY=' /data/coolify/source/.env
```

**No pegues la salida de estos comandos en tickets, correos o chats.**

### 1.2 Permisos correctos

El instalador oficial deja `source/` con `chmod -R 700` y propietario `9999:root`
(que es el UID del usuario del contenedor `coolify`). El script
`post-instalacion.sh` lo verifica.

```bash
sudo stat -c '%U:%G %a %n' /data/coolify/source/.env
```

---

## 2. Variables del kit de Hefesto

Estas son las que usa `scripts/*.sh`. Son opcionales: todas tienen valor por
defecto.

| Variable | Por defecto | Para qué | Obligatoria |
|---|---|---|---|
| `COOLIFY_DATA_DIR` | `/data/coolify` | Carpeta de datos de Coolify que se respalda o se restaura | No |
| `BACKUP_ROOT` | `/data/backups/coolify` | Carpeta donde se dejan los respaldos | No |
| `TZ` | `America/Santiago` | Zona horaria en `ejemplos/compose-aplicacion-ejemplo.yaml` | No |
| `COOLIFY_URL` | — | URL de la instancia, si se usa la API | Solo si automatizas con la API |
| `COOLIFY_TOKEN` | — | Token de la API (`<id>\|<secreto>`) | Solo si automatizas con la API |
| `BACKUP_ROOT` en `config/coolify-backup.service` | `/data/backups/coolify` | Ruta que usa la unidad systemd | Revisar al instalar |

Plantilla: [`.env.example`](../.env.example) (sin ningún secreto real).

### 2.1 Regla dura

`BACKUP_ROOT` **nunca** debe estar dentro de `COOLIFY_DATA_DIR`: el respaldo se
copiaría a sí mismo. `backup-coolify.sh` lo comprueba y aborta.

```bash
# Copia de trabajo: probar un respaldo a otra ruta
sudo BACKUP_ROOT=/mnt/disco-externo/backups ./scripts/backup-coolify.sh --destino /mnt/disco-externo/backups
```

---

## 3. Cómo generar valores seguros, por si hace falta

Si alguna vez hay que generar un valor nuevo:

```bash
openssl rand -hex 32        # 64 caracteres hexadecimales (estilo APP_KEY)
openssl rand -base64 32     # 43 caracteres base64
openssl rand -base64 24     # contraseña legible
```

**Nunca** reemplaces el `APP_KEY` por uno generado a mano. Es una llave de cifrado,
no un token: si la cambias, los secretos ya guardados dejan de poder leerse y la
instancia queda inutilizable. Si se perdió, la recuperación correcta es
restaurar el `.env` del respaldo. Ver
[`05-RESPALDOS-Y-RESTAURACION.md`](05-RESPALDOS-Y-RESTAURACION.md).

---

## 4. La API de Coolify

Resumen operativo; el detalle está en
[`02-INSTALACION-COOLIFY.md`](02-INSTALACION-COOLIFY.md), sección 6.

- La API se habilita en el panel antes de poder usarla.
- El token se crea en el panel, con permisos mínimos (`read` si solo consultas).
- Se manda como `Authorization: Bearer <id>|<secreto>`.
- Es una credencial de pleno acceso al panel: trátala como la clave del banco.

---

## 5. Pendiente de verificar

- No se probó ningún valor de `AUTOUPDATE` en un panel real. Lo que se afirma es
  lo que dice la documentación de actualización (la opción de frecuencia
  desaparece si `AUTOUPDATE` está definido en el `.env`).
- No se verificó el comportamiento del panel si `REGISTRY_URL` apunta a un
  registro privado.
