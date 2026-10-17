# VERSION.md

Kit **Hefesto — VPS administrado (Coolify)**, versión del kit **1.0.0**.

Este documento fija las versiones que el kit declara como verificadas y explica
de dónde sale cada una. Cualquier número que no aparezca aquí con su fuente se
trata como **no verificado**.

---

## 1. Versiones del kit

| Elemento | Versión | Estado |
|---|---|---|
| Kit Hefesto (este paquete) | 1.0.0 | Preparado, sin despliegue |
| Coolify (panel) | **v4.4.6** | Verificada el 2026-10-16 |
| Coolify (rama nightly) | 4.5-rc.1 | No se usa en operación |
| Coolify helper | 1.0.17 | Verificada, la usa el propio panel |
| Coolify sentinel | 1.0.2 | Verificada |
| Traefik (proxy) | v3.7 → 3.7.13 | Versión que el panel resuelve |
| PostgreSQL del panel | `postgres:15-alpine` | Definido por upstream |
| Redis del panel | `redis:7-alpine` | Definido por upstream |
| Docker mínimo | **24** | Exigido por el instalador oficial |
| nginx (solo ejemplo) | `1.31.7-alpine` | Etiqueta de Docker Hub, 2026-10-16 |

### Fuentes

- **Coolify v4.4.6** — `https://api.github.com/repos/coollabsio/coolify/releases/latest`
  devolvió `"tag_name": "v4.4.6"`, `"prerelease": false`, `"published_at": "2026-10-09T13:07:32Z"`.
- **Versiones de Coolify, helper, sentinel y Traefik** — `https://cdn.coollabs.io/coolify/versions.json`
  (el mismo archivo que el instalador y el panel consultan).
- **Docker mínimo 24** — variable `MIN_DOCKER_VERSION=24` en
  `https://cdn.coollabs.io/coolify/install.sh`.
- **Postgres y Redis del panel** — servicio `postgres` (imagen `postgres:15-alpine`,
  contenedor `coolify-db`) y servicio `redis` (imagen `redis:7-alpine`, contenedor
  `coolify-redis`) en `https://cdn.coollabs.io/coolify/docker-compose.yml`.
- **nginx 1.31.7-alpine** — etiqueta existente en Docker Hub, consultada el 2026-10-16
  (`https://hub.docker.com/v2/repositories/library/nginx/tags`), digest del manifiesto
  `sha256:892bb2152464f0c5d8972593a5f5afaf8054552580b699d95f8ff4af08c2d33d`.

---

## 2. Cómo se fijó la versión del panel

Coolify se instala con su script oficial, no con un `compose.yaml` nuestro. El
script oficial:

1. Descarga `docker-compose.yml` y `docker-compose.prod.yml` a
   `/data/coolify/source/`.
2. Genera `/data/coolify/source/.env`.
3. Ejecuta `upgrade.sh`, que es quien decide la imagen final del contenedor.

El `docker-compose.prod.yml` oficial usa:

```
image: ${REGISTRY_URL:-docker.io}/coollabsio/coolify:${LATEST_IMAGE:-latest}
```

Es decir, **por omisión la imagen queda en `:latest`**. El kit NO modifica ese
comportamiento. Para operación controlada, la versión se fija en el momento de
instalar, pasando el número explícito:

```bash
# Actualización a una versión concreta (los 4 argumentos son del upgrade.sh oficial):
bash /data/coolify/source/upgrade.sh v4.4.6 1.0.17 docker.io false
```

- `$1` versión de la imagen del panel.
- `$2` versión del helper.
- `$3` registro (por omisión se lee `REGISTRY_URL` del `.env`, o `docker.io`).
- `$4` si se salta el respaldo previo (`true` lo salta). **No lo saltes.**

Recomendación de operación: fijar siempre la versión en el paso de instalación y
dejar la actualización como una tarea programada de Hefesto, no automática.

---

## 3. Lo que este kit NO fija (y por qué)

- **La imagen del proxy.** `coolify-proxy` no se crea desde el compose base: el
  panel lo genera en `/data/coolify/proxy/` cuando se configura el proxy de un
  servidor, y elige la versión de Traefik por su cuenta.
- **Las imágenes de las aplicaciones que despliega el cliente.** Coolify las
  resuelve en cada despliegue; fijar cada app es una decisión por proyecto, no
  del kit del panel.

---

## 4. Estado del kit

**kit preparado**. Los scripts se revisaron sintácticamente y se ejecutaron solo
en sus modos de lectura. **No se instaló Coolify en ningún servidor**, porque en
el entorno de desarrollo no hay servidor ni Docker. El detalle está en
`docs/07-PRUEBAS-DE-ACEPTACION.md`.
