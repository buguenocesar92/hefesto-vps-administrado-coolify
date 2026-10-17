# 10 — Licencias y fuentes

Todo lo que este kit afirma sobre Coolify sale de las fuentes de esta página.
Cada afirmación del kit es rastreable hasta aquí.

---

## 1. Licencia de Coolify

**Apache License 2.0.**

- Verificado en la API de GitHub del repositorio:
  `https://api.github.com/repos/coollabsio/coolify/license` →
  `"license": {"key": "apache-2.0", "spdx_id": "Apache-2.0"}`.
- Texto oficial: <https://github.com/coollabsio/coolify/blob/main/LICENSE>
- Texto de la licencia: <https://www.apache.org/licenses/LICENSE-2.0>

### Qué exige realmente

| Obligación | ¿Aplica a Hefesto? |
|---|---|
| Dar crédito al autor original | **Sí.** Este kit y cualquier material comercial deben mencionar que Coolify es de coollabsio y es Apache-2.0 |
| Indicar modificaciones | **Sí, si las hubiera.** Este kit **no modifica** el código de Coolify |
| Distribuir el texto de la licencia | **No.** Este kit no distribuye código de Coolify |
| Publicar el código propio | **No.** Apache-2.0 no es copyleft |
| Conceder patentes | Viene en la licencia; no hay acción para Hefesto |
| Sin garantía | Se entrega tal cual; no hay respaldo del autor sobre el funcionamiento |

### Lo que la licencia NO impone

No hay límite de servidores, de proyectos, de usuarios ni de sitios en la versión
self-hosted. La licencia Apache-2.0 es una licencia de uso, no un plan comercial
por niveles.

---

## 2. Componentes que usa la instalación

Definidos por el compose oficial que descarga el instalador, no por el kit.

| Componente | Licencia | Fuente oficial | Nota |
|---|---|---|---|
| Docker Engine | Apache-2.0 | <https://github.com/moby/moby> | Requiere versión 24+ |
| PostgreSQL (imagen `postgres:15-alpine`) | Licencia PostgreSQL | <https://www.postgresql.org/about/licence/> | Licencia tipo BSD, copyleft suave |
| Redis (imagen `redis:7-alpine`) | **Depende de la versión resuelta** | <https://redis.io/legal/licenses/> | Redis cambió su licencia varias veces: **verificar en el servidor** |
| Traefik Proxy (`coolify-proxy`) | MIT | <https://github.com/traefik/traefik/blob/master/LICENSE.md> | Lo crea el panel, no el kit |
| Coolify Helper | Licencia del proyecto Coolify | <https://github.com/coollabsio/coolify> | Binario del proyecto |
| Coolify Sentinel | Licencia del proyecto Coolify | <https://github.com/coollabsio/coolify> | Binario del proyecto |

### Cómo verificar la versión real de Redis en el servidor

```bash
docker inspect --format '{{.Config.Image}}' coolify-redis
```

Si la imagen dice `redis:7-alpine`, la versión exacta se resuelve en el momento
del despliegue. Redis cambió de licencia entre versiones mayores, así que
**no se afirma aquí cuál aplica** sin verlo en el servidor.

---

## 3. Material de demostración

| Elemento | Licencia | Fuente |
|---|---|---|
| nginx (solo en `ejemplos/`) | BSD de 2 cláusulas | <https://nginx.org/LICENSE> |
| Etiqueta usada | `nginx:1.31.7-alpine` | Docker Hub, 2026-10-16 |

La imagen nginx **no se descarga ni se despliega** por este kit: aparece solo como
texto en un archivo de ejemplo.

---

## 4. Fuentes de Coolify usadas en este kit

Todas consultadas el 2026-10-16.

| Tema | Fuente |
|---|---|
| Requisitos, SO soportado, instalación | <https://coolify.io/docs/start-with-self-hosted> |
| Puertos del firewall | <https://coolify.io/docs/core/infrastructure/servers/firewall> |
| Versión estable | `https://api.github.com/repos/coollabsio/coolify/releases/latest` |
| Versiones de componentes | <https://cdn.coollabs.io/coolify/versions.json> |
| Script de instalación | <https://cdn.coollabs.io/coolify/install.sh> |
| Compose del panel | <https://cdn.coollabs.io/coolify/docker-compose.yml> y `docker-compose.prod.yml` |
| Plantilla de secretos | <https://cdn.coollabs.io/coolify/.env.production> |
| Script de actualización | <https://cdn.coollabs.io/coolify/upgrade.sh> |
| Actualización desde el panel | <https://coolify.io/docs/core/instance-management/update> |
| Ajustes de instancia (URL, HTTPS) | <https://coolify.io/docs/core/instance-management/instance-settings> |
| Respaldo nativo | <https://coolify.io/docs/core/backup-and-recovery/instance-backup> |
| Restauración oficial | <https://coolify.io/docs/core/backup-and-recovery/instance-restore> |
| API: autorización | <https://coolify.io/docs/api/authorization> |
| API: referencia general | <https://coolify.io/docs/api/> |
| Self-hosted vs. Cloud | <https://coolify.io/docs/usage> |
| Código fuente (rutas, middleware) | `https://github.com/coollabsio/coolify` rama `v4.x`: `routes/api.php`, `app/Providers/RouteServiceProvider.php`, `app/Http/Kernel.php` |

---

## 5. Lo que es de Hefesto

| Archivo | Autoría |
|---|---|
| `scripts/instalar-coolify.sh` | Hefesto Studio |
| `scripts/backup-coolify.sh` | Hefesto Studio |
| `scripts/restore-coolify.sh` | Hefesto Studio |
| `scripts/post-instalacion.sh` | Hefesto Studio |
| `config/coolify-backup.service` | Hefesto Studio |
| `config/coolify-backup.timer` | Hefesto Studio |
| `ejemplos/compose-aplicacion-ejemplo.yaml` | Hefesto Studio (demostración) |
| Toda la carpeta `docs/` | Hefesto Studio |
| `README.md`, `VERSION.md`, `LICENCIAS.md`, `.env.example`, `.gitignore` | Hefesto Studio |

Ninguno de estos archivos contiene código de Coolify. El panel se descarga desde
su canal oficial y se instala sin modificarlo.

---

## 6. Obligaciones prácticas

1. **Atribución.** En cualquier material comercial: "Coolify, de coollabsio,
   Apache-2.0; operación a cargo de Hefesto Studio."
2. **No quitar avisos** de copyright si alguna vez se copia o modifica un
   archivo de terceros.
3. **El nombre no es nuestro.** Decir "Coolify, panel open source" es correcto.
   Sugerir que Coolify es un producto de Hefesto, no.
4. **No redistribuir Coolify** como parte de este paquete. Este kit no lo
   incluye.

---

## 7. Cómo mantener esta página al día

Antes de cada despliegue comercial:

1. Consultar de nuevo `releases/latest` y `versions.json`.
2. Actualizar [`VERSION.md`](../VERSION.md) con la fecha.
3. Si cambió el comportamiento del instalador, releer
   `install.sh` y corregir [`02-INSTALACION-COOLIFY.md`](02-INSTALACION-COOLIFY.md).
4. Revisar la versión de Redis en el servidor y ajustar la nota de la sección 2.

Las cifras de este kit tienen fecha. Sin fecha, un documento técnico es una
opinión.
