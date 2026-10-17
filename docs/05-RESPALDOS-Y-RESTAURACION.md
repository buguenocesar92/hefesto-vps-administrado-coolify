# 05 — Respaldos y restauración

Este es el documento más importante del kit. Un respaldo que nunca se probó no es
un respaldo: es una carpeta con la esperanza de que sirva.

---

## 1. Qué es persistente

Todo lo que Coolify sabe de la instancia vive bajo `/data/coolify`
(verificado en <https://cdn.coollabs.io/coolify/install.sh>).

| Ruta | Qué guarda | Crítico |
|---|---|---|
| `/data/coolify/source/.env` | **Secretos de instalación**, incluido `APP_KEY` | Sí, crítico |
| `/data/coolify/source/` | `docker-compose.yml`, `docker-compose.prod.yml`, `.env.production`, `upgrade.sh`, `upgrade-postgres.sh`, logs | Sí |
| `/data/coolify/ssh/keys/` | Claves SSH que usa Coolify para conectarse a los servidores | Sí, crítico |
| `/data/coolify/proxy/` | Configuración del proxy (la crea el panel) | Sí |
| `/data/coolify/applications/`, `/databases/`, `/services/` | Datos de recursos | Sí |
| `/data/coolify/backups/` | Respaldos generados por el panel | No (se puede regenerar) |
| `/data/coolify/images/` | Imágenes de recursos | No (se regeneran) |

Además, en el **volumen Docker** `coolify-db` vive el PostgreSQL interno del
panel (`postgres:15-alpine`). Ese volumen **no** está dentro de `/data/coolify`:
por eso el respaldo lo hace `pg_dump` y no una copia de archivos.

---

## 2. Qué NO se respalda, y por qué

| Fuera del alcance | Por qué |
|---|---|
| **Los datos de las aplicaciones y bases que despliega el cliente** | No son de la instancia del panel. Upstream lo dice: el respaldo de la instancia "does not back up data stored inside your applications, databases, or volumes" |
| **Los volúmenes Docker de las apps** | Idem |
| **El APP_KEY por sí solo** | No viaja en el respaldo de la base. Es un archivo aparte: `/data/coolify/source/.env` |
| **`~/.ssh/authorized_keys` del servidor** | Está fuera de `/data/coolify`. Upstream lo pide aparte al restaurar en otra máquina |

**Consecuencia comercial:** el VPS administrado de Hefesto tiene que incluir el
respaldo de los datos del cliente, no solo el del panel. Un cliente cuya base de
datos se pierde porque nadie respaldó el volumen no recibe un producto entero.

---

## 3. Los tres respaldos que hay que tener

| # | Qué | Dónde | Qué cubre |
|---|---|---|---|
| 1 | **Respaldo nativo de Coolify** | Panel → `Settings > Backup` → `Configure backup` (diario, con copia S3) | La base de datos del panel |
| 2 | **Respaldo de disco del kit** | `scripts/backup-coolify.sh` | Base de datos + `/data/coolify` completo (incluye `.env` y `ssh/keys`) |
| 3 | **Los datos de las aplicaciones** | A definir por proyecto | Lo que el cliente aloja |

Fuente del respaldo nativo: <https://coolify.io/docs/core/backup-and-recovery/instance-backup>

---

## 4. Cómo obtener una copia coherente

Un respaldo mal tomado es peor que no tener ninguno: da una sensación de
seguridad falsa. El script de este kit coordina a los escritores:

1. **Detiene a los que escriben estado**: los contenedores `coolify`,
   `coolify-redis` y `coolify-proxy` (si existen). El panel queda unos segundos
   sin responder, a propósito.
2. **No detiene `coolify-db`**: es quien produce el volcado.
3. **Vuelca la base** con `pg_dump` en formato `custom`, que es el formato que
   espera el `pg_restore` oficial documentado por upstream.
4. **Verifica el volcado** ejecutando `pg_restore --list` sobre él: si no es
   legible, el respaldo falla.
5. **Copia `/data/coolify`** con los atributos intactos.
6. **Calcula SHA-256** de cada archivo y **los verifica**.
7. **Marca el respaldo como completo solo al final**, y lo publica con un
   `mv` atómico: o aparece entero y verificado, o no aparece.

```bash
sudo ./scripts/backup-coolify.sh
# o a otra ruta (por ejemplo, a un disco montado):
sudo ./scripts/backup-coolify.sh --destino /mnt/disco-externo/backups
```

Durante la copia el panel está unos segundos caído. Es intencional: copiar
archivos mientras el panel escribe produce respaldos inconsistentes.

### 4.1 Estructura de un respaldo

```
/data/backups/coolify/20261016T031700Z/
├── MANIFESTO.txt     # fecha, servidor, imagen del panel, tamaño, origen
├── SHA256SUMS        # SHA-256 de todos los archivos
├── COMPLETO          # se escribe SOLO al terminar bien
├── coolify-db.dmp    # volcado pg_dump en formato custom
└── data/             # copia íntegra de /data/coolify
    ├── source/.env
    ├── ssh/keys/
    └── ...
```

Mientras se construye, la carpeta se llama `.incompleto-<marca>` y no tiene
`COMPLETO`. Si el proceso se corta, no hay respaldo bueno: hay una carpeta incompleta que se
puede borrar sin miedo.

### 4.2 Verificación

```bash
cd /data/backups/coolify/20261016T031700Z
sha256sum -c SHA256SUMS          # debe imprimir "OK" en cada archivo
ls -la COMPLETO                  # debe existir
```

Y de vez en cuando, **restaura de verdad** en un servidor de prueba. Ver
sección 7.

---

## 5. Secretos que hay que conservar aparte

| Secreto | Dónde está | Por qué aparte |
|---|---|---|
| `APP_KEY` | `/data/coolify/source/.env` | Cifra las credenciales guardadas en la base. **Sin él, el respaldo de la base no se puede recuperar** |
| Contraseña de la base interna | mismo archivo | Si hay que reconstruir el contenedor |
| Contraseña de Redis | mismo archivo | Ídem |
| Claves SSH de la instancia | `/data/coolify/ssh/keys/` y `~/.ssh/authorized_keys` | Sin ellas no se puede reconectar a los servidores del cliente |
| Versión del panel al momento del respaldo | imagen del contenedor `coolify`, registrada en `MANIFESTO.txt` | Restaurar con otra versión puede migrar la base de forma irreversible |

Upstream lo dice de forma directa: copia la línea completa `APP_KEY=...` a un
lugar seguro **fuera del servidor**, y trátala como una contraseña.

```bash
sudo grep '^APP_KEY=' /data/coolify/source/.env
```

**Nunca** imprimas ese valor en un ticket, un chat o un correo.

---

## 6. Restauración

El script de este kit es deliberadamente conservador:

```bash
# 1. Revisar qué haría, sin ejecutar nada
sudo ./scripts/restore-coolify.sh --help

# 2. Restaurar archivos (la base de datos NO se toca)
sudo ./scripts/restore-coolify.sh --respaldo /data/backups/coolify/20261016T031700Z
```

### 6.1 Qué hace y qué no hace

| Comportamiento | Implementado |
|---|---|
| Verifica que exista `COMPLETO` | Sí. Sin `COMPLETO`, no restaura nada |
| Verifica todos los SHA-256 antes de escribir | Sí |
| Valida rutas antes de extraer (sin `/` absolutos ni `..`) | Sí, también para `.tar.gz` |
| Rechaza destinos ocupados | Sí, salvo `--force` |
| Compara el `APP_KEY` del destino con el del respaldo | Sí, **sin mostrar valores** (compara huellas) |
| Ejecuta `DROP` o `pg_restore` por su cuenta | **No.** Requiere `--ejecutar-base` y escribir `RESTAURAR` |
| Deja los servicios detenidos al terminar | Sí, a propósito |

### 6.2 Por qué no ejecuta el `pg_restore` solo

El comando oficial de upstream es:

```bash
docker exec -i coolify-db pg_restore \
  --clean --if-exists --exit-on-error --no-acl --no-owner \
  --username=coolify --dbname=coolify < "$BACKUP_PATH"
```

Fuente: <https://coolify.io/docs/core/backup-and-recovery/instance-restore>

`--clean --if-exists` **borra los objetos actuales de la base antes de cargar el
respaldo**. Es decir: equivale a un `DROP` selectivo. Upstream mismo advierte que
los datos actuales se reemplazan.

Por eso este kit no lo ejecuta solo. El operador tiene que pedirlo:

```bash
sudo ./scripts/restore-coolify.sh \
     --respaldo /data/backups/coolify/20261016T031700Z \
     --ejecutar-base
# y escribir RESTAURAR cuando lo pida.
```

### 6.3 Procedimiento completo de recuperación tras una pérdida del servidor

1. Servidor nuevo, con Docker instalado
   ([`01-INSTALACION-DOCKER.md`](01-INSTALACION-DOCKER.md)).
2. Copiar el respaldo al servidor nuevo.
3. Verificar los SHA-256.
4. `sudo ./scripts/restore-coolify.sh --respaldo <ruta>` — restaura archivos y
   deja todo detenido.
5. Revisar, **con los servicios todavía apagados**:
   - Que `/data/coolify/source/.env` exista con permisos 700.
   - Que el `APP_KEY` sea el de esta instancia.
   - Que `ssh/keys/` tenga las claves originales.
6. Si hace falta, levantar solo la base:
   `docker start coolify-db`
7. Ejecutar el respaldo de la base con `--ejecutar-base`.
8. Levantar el resto:
   `docker start coolify && docker start coolify-redis`
9. `sudo ./scripts/post-instalacion.sh`
10. Revisar desde el panel que los proyectos y recursos estén.
11. Verificar que Coolify todavía puede conectarse por SSH a los servidores.

---

## 7. Probar una restauración, de verdad

**La única forma de saber que un respaldo sirve es restaurarlo.** Una vez al
trimestre, en un servidor desechable:

```bash
# En el servidor de prueba, con el kit copiado
sudo ./scripts/restore-coolify.sh --respaldo <respaldo> --destino /data/coolify-prueba
```

Anotar en la bitácora: fecha, respaldo usado, si la restauración terminó, cuánto
tardó, y qué se corrigió. Un cliente que nunca vio una restauración ensayada
no tiene respaldo, tiene una carpeta.

---

## 8. Ante un fallo parcial

| Situación | Qué hacer |
|---|---|
| La copia se cortó (sin energía, disco lleno) | No hay `COMPLETO`. Borra la carpeta `.incompleto-*`. No sirve de nada. |
| Falla `pg_dump` | El script aborta y borra el staging. **No** hay respaldo bueno. Revisa disco y que `coolify-db` esté sano |
| Falla la verificación SHA-256 | **Almacenamiento dañado.** No uses ese respaldo. Copia los datos a otro medio y vuelve a generar el respaldo |
| Falla `pg_restore` con `--exit-on-error` | La base quedó en estado parcial. **No sigas**. Restaura la base desde otro respaldo, o reconstruye la instancia |
| La instancia funciona pero las credenciales guardadas no se descifran | Casi seguro es un `APP_KEY` distinto. Restaura el `.env` correcto |
| El panel levanta pero no conecta a los servidores | Faltan `ssh/keys/`. Revísalo antes de tocar nada más |

Nunca "arregles" una base a medias ejecutando comandos sueltos sin documentar: en
un incidente, el árbol de decisiones escrito vale más que el atajo.

---

## 9. Automatización

Ver [`config/`](../config/README.md): unidades systemd para el respaldo diario.

```bash
sudo cp config/coolify-backup.service config/coolify-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now coolify-backup.timer
```

Además del respaldo local, conviene una **copia fuera del servidor**. Upstream
ofrece copia S3 para su respaldo nativo; para el respaldo de disco del kit,
copiar la carpeta a almacenamiento externo es responsabilidad de la operación.

**Un respaldo que vive en el mismo servidor que respalda no sobrevive a la
pérdida de ese servidor.**

---

## 10. Pendiente de verificación

- **Los scripts no se ejecutaron contra una instancia real.** No hay servidor ni
  Docker en el entorno donde se escribió el kit. Ver
  [`07-PRUEBAS-DE-ACEPTACION.md`](07-PRUEBAS-DE-ACEPTACION.md).
- No se midió el tiempo de respaldo en un servidor de 2 GB (el mínimo
  documentado). Puede ser relevante para decidir la ventana de mantenimiento.
- No se probó una restauración completa desde cero en un servidor nuevo.
