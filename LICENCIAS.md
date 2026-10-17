# LICENCIAS.md

Este kit es material de **Hefesto Studio**. Coolify, Docker, PostgreSQL, Redis,
Traefik y nginx son proyectos de terceros con sus propias licencias.

---

## 1. Qué es de Hefesto y qué es de terceros

| Componente | Origen | Licencia | Qué implica |
|---|---|---|---|
| Scripts (`scripts/*.sh`) | **Hefesto Studio** | Licencia de Hefesto | Código propio del estudio |
| Documentación (`docs/`, `README.md`) | **Hefesto Studio** | Licencia de Hefesto | Texto propio |
| `config/` (unidades systemd) | **Hefesto Studio** | Licencia de Hefesto | Configuración propia |
| `ejemplos/` | **Hefesto Studio** | Licencia de Hefesto | Material de demostración |
| **Coolify** (el panel) | coollabsio/coolify | **Apache-2.0** | Ver abajo |
| Docker Engine | Docker Inc. | Apache-2.0 | Componente del sistema |
| PostgreSQL (base del panel) | The PostgreSQL Global Development Group | Licencia PostgreSQL | Copyleft suave |
| Redis (caché del panel) | Redis Ltd. | LicenciasBSD de 3 cláusulas ("RSALv2/SSPLv1" en versiones recientes) | Verificar la versión exacta desplegada |
| Traefik Proxy (proxy) | Traefik Labs | MIT | Proxy que usa Coolify |
| nginx (solo en el ejemplo) | F5 / nginx | BSD de 2 cláusulas | Solo aparece en `ejemplos/` |

**Este kit no incluye el código de Coolify.** Solo incluye scripts y
documentación de Hefesto que ayuda a instalarlo y operarlo. Coolify se descarga
directamente desde su canal oficial.

---

## 2. Coolify: Apache-2.0

Verificado en la API de GitHub del propio repositorio:
`https://api.github.com/repos/coollabsio/coolify/license` devuelve
`"spdx_id": "Apache-2.0"`, y el archivo `LICENSE` del repositorio es la
licencia Apache 2.0.

### Qué obliga realmente la Apache-2.0 en este caso

- **Atribución:** hay que dar crédito a Coolify (Coolify, de coollabsio) y
  indicar si se hicieron modificaciones. Este documento y el README lo hacen.
- **Declaración de cambios:** si Hefesto modificara el código de Coolify, debe
  indicarlo. **No lo hacemos**: el panel se instala sin tocarlo.
- **Sin copyleft:** la Apache-2.0 no obliga a publicar el código de quien la usa.
  Puedes usar Coolify en un servicio comercial y cobrar por operarlo.
- **Patentes:** la licencia incluye una concesión de patentes del titular.
- **Sin garantía:** el software se entrega "tal cual".

### Lo que Coolify NO es

Coolify **no es un proveedor de hosting**. Es un panel que administra servidores
que tú aportas y pagas. No hay versión "edición libre" recortada del panel
self-hosted: la documentación de upstream describe la opción self-hosted como
gratuita salvo los costos del servidor.

---

## 3. Componentes internos del panel

Estos no los elige Hefesto: los define el `docker-compose` oficial que descarga
el instalador. Se listan para que la operación de licencias sea consciente.

- **PostgreSQL 15 Alpine** (`postgres:15-alpine`, contenedor `coolify-db`):
  Licencia PostgreSQL.
- **Redis 7 Alpine** (`redis:7-alpine`, contenedor `coolify-redis`): la
  licencia depende de la versión exacta que resuelva la imagen. **Verificar en
  el servidor antes de entregar**:
  ```bash
  docker inspect --format '{{.Config.Image}}' coolify-redis
  ```
  Redis cambió su licencia varias veces; el kit no asume cuál es.
- **Traefik Proxy** (contenedor `coolify-proxy`): MIT. Lo crea el panel, no el kit.
- **Helper de Coolify** y **Sentinel**: binarios del propio proyecto Coolify,
  bajo la licencia del repositorio.

---

## 4. Obligaciones prácticas para Hefesto

1. **No redistribuir Coolify como si fuera nuestro.** En cualquier material
   comercial (web, contrato, presentación) hay que aclarar que Coolify es un
   proyecto Apache-2.0 de coollabsio y que Hefesto opera la instancia.
2. **No quitar los avisos de copyright** de los archivos de terceros si se
   copian o modifican.
3. **El nombre "Coolify" no es nuestro.** Decir " VPS administrado por Hefesto
   con Coolify" es correcto; insinuar que Coolify es un producto de Hefesto, no.
4. **Este kit no incluye código de terceros**, así que la obligación práctica es
   de atribución, no de copia de fuentes.

---

## 5. Fuentes oficiales de licencia

- Coolify (Apache-2.0): `https://github.com/coollabsio/coolify/blob/main/LICENSE`
- Docker Engine (Apache-2.0): `https://github.com/moby/moby`
- PostgreSQL: `https://www.postgresql.org/about/licence/`
- Redis: `https://redis.io/legal/licenses/`
- Traefik (MIT): `https://github.com/traefik/traefik/blob/master/LICENSE.md`
- nginx (BSD-2-Clause): `https://nginx.org/LICENSE`
- Licencia Apache-2.0 (texto completo): `https://www.apache.org/licenses/LICENSE-2.0`

Detalle ampliado en `docs/10-LICENCIAS-Y-FUENTES.md`.
