# 07 — Pruebas de aceptación

Este documento separa, sin ambigüedad, **lo que realmente se ejecutó** de **lo
que queda pendiente**. La regla del kit es simple: no se presenta lo pendiente
como hecho.

---

## 0. Estado

**kit preparado.**

En el entorno donde se construyó este kit **no hay servidor ni Docker**. Por lo
tanto: **no se instaló Coolify, no se levantó ningún contenedor, no se hizo
ningún respaldo ni ninguna restauración reales.**

Todo lo afirmado sobre el comportamiento de Coolify proviene de **leer la
documentación oficial y el código fuente de los scripts oficiales**, con la
fuente citada en cada documento.

---

## 1. Realmente ejecutado (verificable, con cómo reproducirlo)

### 1.1 Sintaxis de los scripts

**Ejecutado.** `bash -n` sobre los cuatro scripts, en bash 5.3.9.

```bash
cd scripts
for f in instalar-coolify.sh backup-coolify.sh restore-coolify.sh post-instalacion.sh; do
  bash -n "./$f" && echo "OK $f"
done
```

Resultado: los cuatro pasaron sin errores.

### 1.2 Modo de solo mostrar el comando oficial

**Ejecutado.**

```bash
./scripts/instalar-coolify.sh --solo-comando
```

Salida real:

```
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
```

Código de salida `0`. Confirma que el script **no descarga ni ejecuta nada**
en ese modo.

### 1.3 Ayuda de los scripts

**Ejecutado.** `--help` en `instalar-coolify.sh` y `restore-coolify.sh`: ambos
muestran el uso y salen con código `0`. `restore-coolify.sh` sin argumentos
imprime el error `Falta --respaldo.` y sale con código `1`, como está diseñado.

### 1.4 Revisión de prerrequisitos sin instalar

**Ejecutado** en un entorno Linux (WSL2), que es la única máquina disponible:

```bash
./scripts/instalar-coolify.sh --revision
```

Comportamiento observado (resumen):

- Detectó Linux, familia Debian/Ubuntu, CPU y RAM, espacio en disco.
- Detectó correctamente la versión de Ubuntu como **no-LTS** y emitió el aviso
  correspondiente.
- Detectó que **no hay Docker** y emitió `[ERROR] Docker no está instalado`.
- Detectó que `/data/coolify` no existe y lo reportó como instalación nueva.
- Resumió `Errores: 1 | Avisos: 1` y **salió con código 1 sin instalar nada**.

Esto confirma el comportamiento de seguridad más importante del script: **con un
error de prerrequisito, no instala.**

### 1.5 Verificación de hechos contra fuentes oficiales

**Ejecutado.** Cada dato de este kit se comprobó contra su fuente:

| Dato | Cómo se verificó | Resultado |
|---|---|---|
| Versión estable de Coolify | `api.github.com/repos/coollabsio/coolify/releases/latest` | `v4.4.6`, `prerelease: false`, publicada 2026-10-09 |
| Versiones de helper, sentinel, Traefik | `cdn.coollabs.io/coolify/versions.json` | helper 1.0.17, sentinel 1.0.2, Traefik v3.7 = 3.7.13 |
| Requisitos de sistema | Documentación oficial | 2 vCPU, 2 GB RAM, 10 GB disco |
| Docker mínimo | `MIN_DOCKER_VERSION=24` en `install.sh` | 24 |
| Comportamiento del instalador | Lectura completa de `install.sh` | Directorios, permisos, secretos generados, `.env` en `/data/coolify/source/` |
| Contenedores e imágenes | `docker-compose.yml` y `docker-compose.prod.yml` oficiales | `coolify`, `coolify-db` (postgres:15-alpine), `coolify-redis` (redis:7-alpine) |
| Puertos | Página oficial de firewall | 22, 80, 443, 8000, 6001, 6002, y el cierre de 8000/6001/6002 tras el proxy |
| Restauración oficial | Página oficial de restauración | Comando `pg_restore` con `--clean --if-exists --exit-on-error --no-acl --no-owner --username=coolify --dbname=coolify` |
| Firma de `upgrade.sh` | Lectura del script | `upgrade.sh [version] [helper-version] [registry] [skip-backup]` |
| API (prefijo y autenticación) | `routes/api.php`, `app/Providers/RouteServiceProvider.php`, `app/Http/Kernel.php` en la rama `v4.x` | Prefijo `/api`, versión `/api/v1`, `Authorization: Bearer <id>\|<secreto>` |
| Licencia | `api.github.com/repos/coollabsio/coolify/license` | `Apache-2.0` |
| Etiqueta del ejemplo | Docker Hub API | `nginx:1.31.7-alpine` existe |

### 1.6 Ausencia de secretos

**Ejecutado.** Revisión manual de todos los archivos del kit: no hay contraseñas,
tokens ni claves reales. `.env.example` solo trae valores obviamente falsos, y
`.gitignore` excluye `.env`, respaldos, `*.dmp` y archivos de clave.

---

## 2. Pendiente de probar en un servidor real

Nada de esta sección se ejecutó. Es la lista de trabajo del primer despliegue.

### 2.1 Instalación

| # | Prueba | Cómo | Resultado esperado |
|---|---|---|---|
| 1 | Instalación limpia en Ubuntu 24.04 LTS | `./scripts/instalar-coolify.sh --instalar` | Panel en `http://<ip>:8000` |
| 2 | Contenedores esperados | `docker ps` | `coolify`, `coolify-db`, `coolify-redis` arriba; `coolify` en `healthy` |
| 3 | Permisos del `.env` | `stat -c '%U:%G %a' /data/coolify/source/.env` | `9999:root 700` |
| 4 | Health del panel | `curl -fsS http://127.0.0.1:8000/api/health` | Responde |
| 5 | Verificación integral | `./scripts/post-instalacion.sh` | Sin problemas bloqueantes |
| 6 | Instalación en Debian 12 | Igual que 1 | Instala bien |
| 7 | Rechazo en Ubuntu no-LTS | Revisar que solo avise y deje continuar a criterio | Aviso, no error fatal |

### 2.2 Red, dominio y HTTPS

| # | Prueba | Cómo | Resultado esperado |
|---|---|---|---|
| 8 | Certificado TLS del panel | Configurar URL de instancia con `https://` | Certificado válido |
| 9 | Cierre de puertos | Cerrar `8000`, `6001`, `6002` | El panel sigue funcionando por 443 |
| 10 | Terminal web y tiempo real | Tras el cierre de puertos | Ambos siguen funcionando |
| 11 | Proxy y apps | Desplegar el ejemplo y abrir por dominio | Responde con TLS válido |
| 12 | `ufw` + Docker | Activar firewall con las redes de Coolify | No se corta el tráfico del proxy |

### 2.3 Respaldos

| # | Prueba | Cómo | Resultado esperado |
|---|---|---|---|
| 13 | Respaldo completo | `./scripts/backup-coolify.sh` | Carpeta con `MANIFESTO.txt`, `SHA256SUMS`, `COMPLETO` y `coolify-db.dmp` |
| 14 | Verificación de integridad | `sha256sum -c SHA256SUMS` | Todo `OK` |
| 15 | Contenedores recuperados | El script los vuelve a levantar | Vuelven a `running` |
| 16 | Volcado legible | `pg_restore --list` sobre el `.dmp` | Lista objetos |
| 17 | Tamaño y duración | Cronometrar en un servidor de 2 GB | Anotar para la ventana de mantenimiento |
| 18 | Respaldo programado | `systemctl enable --now coolify-backup.timer` | Se ejecuta y queda registrado |

### 2.4 Restauración

| # | Prueba | Cómo | Resultado esperado |
|---|---|---|---|
| 19 | **Restauración completa desde cero** | Servidor nuevo + `restore-coolify.sh` + `--ejecutar-base` | Instancia recuperada |
| 20 | Rechazo de destino ocupado | Restaurar sobre `/data/coolify` existente | Se niega, código 1 |
| 21 | Rechazo sin `COMPLETO` | Respaldo sin el marcador | Se niega |
| 22 | Detección de `APP_KEY` distinto | Restaurar un `.env` con otra clave | Avisa y bloquea sin `--force` |
| 23 | Servicios detenidos al final | Tras restaurar | `coolify`, `coolify-redis`, `coolify-proxy` apagados |
| 24 | Recepción de `.tar.gz` malicioso | Tar con `../` o ruta absoluta | Se niega antes de extraer |
| 25 | Credenciales descifrables | Tras restaurar, revisar credenciales guardadas | Se descifran (confirma que el `APP_KEY` es el correcto) |

### 2.5 Actualización

| # | Prueba | Cómo | Resultado esperado |
|---|---|---|---|
| 26 | Actualización desde el panel | `Settings → Updates` | Actualiza, panel vuelve en menos de un minuto |
| 27 | Actualización por CLI | `upgrade.sh v4.4.6 1.0.17 docker.io false` | Actualiza y deja log |
| 28 | Reversión | Restaurar respaldo de versión anterior | Se recupera |
| 29 | Comportamiento con `AUTOUPDATE` | Definirlo en el `.env` y abrir `Settings` | La opción de frecuencia desaparece |

### 2.6 Operación y límites

| # | Prueba | Cómo | Resultado esperado |
|---|---|---|---|
| 30 | API habilitada | Crear token de lectura | `GET /api/v1/version` responde |
| 31 | Permisos del token | Token `read` contra una ruta de escritura | Rechazado |
| 32 | Aislamiento entre clientes | Panel con servidores de dos clientes | Confirmar que hay visibilidad cruzada |
| 33 | Cerrar registro | Revisar el panel instalado | Anotar si existe interruptor global |

---

## 3. Lo que este kit no puede prometer

- **Que el respaldo sirva**, hasta que la prueba 19 se ejecute.
- **Un tiempo de instalación o de respaldo**, hasta que se mida en el hardware
  del cliente.
- **Que una versión concreta de Coolify sea estable en el momento del despliegue**:
  hay que volver a leer `versions.json` al momento de instalar.
- **Aislamiento entre clientes** en una instancia compartida: no existe (ver
  [`04-PRIMERA-CUENTA-Y-USUARIOS.md`](04-PRIMERA-CUENTA-Y-USUARIOS.md)).

---

## 4. Cómo actualizar este documento

Cada vez que se ejecute una prueba de la sección 2, moverla a la sección 1 con
la fecha, el comando exacto y el resultado observado. Si una prueba falla,
dejarlo anotado como fallo, no borrar el rastro.
