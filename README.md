# VPS administrado Hefesto — Kit de despliegue y operación con Coolify

Kit de **Hefesto Studio** para instalar, configurar, respaldar y operar el panel
**Coolify** en un VPS, como parte del servicio comercial **VPS administrado
Hefesto**.

---

## Qué es esto (y qué no es)

**Coolify es el panel open source** para desplegar y administrar aplicaciones,
bases de datos y servicios en servidores propios. Es un proyecto de
[coollabsio/coolify](https://github.com/coollabsio/coolify), bajo licencia
**Apache-2.0**, y no es un producto de Hefesto.

**Este kit es un kit de despliegue**, no el código de Coolify. No incluye el
código fuente del panel ni sus imágenes: los descarga el instalador oficial
directamente de los canales de upstream. Lo que sí es propio de Hefesto:

| Pieza | Qué es |
|---|---|
| `scripts/*.sh` | Cuatro scripts de operación escritos para este servicio |
| `docs/` | La documentación de instalación, operación y respaldo |
| `config/` | Unidades systemd para el respaldo diario |
| `ejemplos/` | Un compose de demostración para explicar Coolify al cliente |
| `.env.example`, `.gitignore`, `VERSION.md`, `LICENCIAS.md` | Metadatos del kit |

Detalle en [`docs/10-LICENCIAS-Y-FUENTES.md`](docs/10-LICENCIAS-Y-FUENTES.md).

---

## Por qué no hay un `compose.yaml` en la raíz

**Coolify no se instala con un `docker compose` propio.** Se instala con el
script oficial:

```bash
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
```

Ese script descarga su propio compose a `/data/coolify/source/`, genera los
secretos en `/data/coolify/source/.env`, crea la red y aplica los permisos que el
contenedor espera. Escribir un `compose.yaml` "de Coolify" en este kit sería
duplicar el oficial y quedar desincronizado en la primera actualización.

Lo que el kit sí incluye:

- `ejemplos/compose-aplicacion-ejemplo.yaml`: un compose **de ejemplo**, para
  mostrar cómo se despliega *una aplicación típica* dentro de Coolify. Está
  marcado como demostración y no instala el panel.

Explicación completa en [`docs/02-INSTALACION-COOLIFY.md`](docs/02-INSTALACION-COOLIFY.md).

---

## Estado del kit

> ## ⚠️ kit preparado
>
> **No se instaló Coolify en ningún servidor.** En el entorno donde se construyó
> este kit no hay servidor ni Docker.
>
> Lo que **sí** se hizo:
> - Los cuatro scripts pasaron `bash -n` (bash 5.3.9).
> - Se ejecutaron sus modos de lectura (`--help`, `--solo-comando`,
>   `--revision`) y se comportaron como se documenta.
> - Cada dato sobre Coolify se verificó contra su fuente oficial (sección
>   siguiente).
>
> Lo que **no** se hizo: instalar, respaldar, restaurar ni desplegar nada.
>
> El detalle está en [`docs/07-PRUEBAS-DE-ACEPTACION.md`](docs/07-PRUEBAS-DE-ACEPTACION.md),
> con una lista de 33 pruebas concretas para el primer despliegue real.

---

## Qué se verificó, y contra qué fuente

Todo consultado: **2026-10-16**.

| Dato | Valor | Fuente |
|---|---|---|
| Versión estable | **v4.4.6** (publicada 2026-10-09, no es prerelease) | `api.github.com/repos/coollabsio/coolify/releases/latest` |
| Requisitos | 2 vCPU, 2 GB RAM, 10 GB de disco (mínimo documentado) | [coolify.io/docs/start-with-self-hosted](https://coolify.io/docs/start-with-self-hosted) |
| Aviso de disco del instalador | 30 GB totales / 20 GB libres | `REQUIRED_TOTAL_SPACE` / `REQUIRED_AVAILABLE_SPACE` en `install.sh` |
| Docker mínimo | 24 | `MIN_DOCKER_VERSION=24` en `install.sh` |
| Contenedores | `coolify`, `coolify-db` (`postgres:15-alpine`), `coolify-redis` (`redis:7-alpine`) | `docker-compose.yml` oficial |
| Datos y secretos | `/data/coolify`, secretos en `/data/coolify/source/.env` | `install.sh` |
| Puertos | 22, 80, 443, 8000, 6001, 6002 | [página de firewall](https://coolify.io/docs/core/infrastructure/servers/firewall) |
| Cierre de puertos | Tras el dominio, se pueden cerrar 8000, 6001 y 6002 | [página de firewall](https://coolify.io/docs/core/infrastructure/servers/firewall) |
| Restauración oficial | `pg_restore --clean --if-exists --exit-on-error --no-acl --no-owner --username=coolify --dbname=coolify` | [página de restauración](https://coolify.io/docs/core/backup-and-recovery/instance-restore) |
| Actualización | `upgrade.sh [version] [helper-version] [registry] [skip-backup]` | `upgrade.sh` oficial |
| API | Prefijo `/api`, versiones `/api/v1/...`, encabezado `Authorization: Bearer <id>\|<secreto>` | `routes/api.php`, `RouteServiceProvider.php`, [docs de autorización](https://coolify.io/docs/api/authorization) |
| Licencia | Apache-2.0, sin límites de servidores o sitios | `api.github.com/.../license` |

Lista completa en [`docs/10-LICENCIAS-Y-FUENTES.md`](docs/10-LICENCIAS-Y-FUENTES.md).

---

## Contenido del paquete

```
hefesto-coolify-vps-gestionado/
├── README.md
├── VERSION.md                     # versiones y su origen
├── LICENCIAS.md                   # licencias y obligaciones
├── .env.example                   # sin ningún secreto real
├── .gitignore
├── config/                        # respaldo diario (systemd)
│   ├── README.md
│   ├── coolify-backup.service
│   └── coolify-backup.timer
├── scripts/                       # operación (chmod +x)
│   ├── instalar-coolify.sh        # verifica prerrequisitos; instala solo si se confirma
│   ├── backup-coolify.sh          # respaldo coherente con manifiesto y SHA-256
│   ├── restore-coolify.sh         # restauración validada, nunca DROP sola
│   └── post-instalacion.sh        # verificación posterior (solo lectura)
├── ejemplos/
│   └── compose-aplicacion-ejemplo.yaml   # DEMOSTRACIÓN, no es el panel
└── docs/
    ├── 01-INSTALACION-DOCKER.md
    ├── 02-INSTALACION-COOLIFY.md
    ├── 03-VARIABLES-Y-COMO-OBTENERLAS.md
    ├── 04-PRIMERA-CUENTA-Y-USUARIOS.md
    ├── 05-RESPALDOS-Y-RESTAURACION.md
    ├── 06-ACTUALIZACIONES-Y-REVERSION.md
    ├── 07-PRUEBAS-DE-ACEPTACION.md
    ├── 08-SERVICIOS-COMERCIALES.md
    ├── 09-EXPORTACION-O-TRASPASO.md
    └── 10-LICENCIAS-Y-FUENTES.md
```

---

## Inicio rápido

```bash
# 0. Copiar el kit al servidor y darle permisos de ejecución
sudo cp -r hefesto-coolify-vps-gestionado /opt/hefesto/coolify-vps-gestionado
cd /opt/hefesto/coolify-vps-gestionado
sudo chmod +x scripts/*.sh

# 1. Docker en el servidor (Ubuntu/Debian)
sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli \
     containerd.io docker-buildx-plugin docker-compose-plugin

# 2. Revisar prerrequisitos. NO instala nada.
sudo ./scripts/instalar-coolify.sh --revision

# 3. Instalar (pide escribir INSTALAR)
sudo ./scripts/instalar-coolify.sh --instalar

# 4. Verificar
sudo ./scripts/post-instalacion.sh

# 5. RESPALDAR, apenas se haya creado la primera cuenta
sudo ./scripts/backup-coolify.sh
sudo grep '^APP_KEY=' /data/coolify/source/.env   # y guárdalo FUERA del servidor
```

El paso 5 no es opcional. **El `APP_KEY` cifra las credenciales guardadas en el
panel: sin él, el respaldo de la base no sirve para recuperar nada.**

### Qué hay que respaldar

| Dónde | Qué | ¿Cubierto por el script del kit? |
|---|---|---|
| `/data/coolify` | Todos los datos de la instancia del panel | Sí |
| `/data/coolify/source/.env` | `APP_KEY` y secretos de instalación | Sí (copia dentro del respaldo) |
| `/data/coolify/ssh/keys/` | Claves SSH de la instancia | Sí |
| Volumen `coolify-db` | Base interna del panel | Sí, vía `pg_dump` |
| **Datos de las apps del cliente** | Volúmenes de aplicaciones y bases | **No.** Responsabilidad del cliente, o de Hefesto si está en el alcance |

Upstream lo dice sin rodeos: el respaldo de la instancia **no** incluye los datos
que viven dentro de las aplicaciones. Ver
[`docs/05-RESPALDOS-Y-RESTAURACION.md`](docs/05-RESPALDOS-Y-RESTAURACION.md).

---

## Requisitos

| Recurso | Mínimo documentado | Recomendado por Hefesto |
|---|---|---|
| CPU | 2 vCPU | 4 vCPU (panel + una app) |
| RAM | 2 GB | 8 GB |
| Disco | 10 GB (el instalador avisa bajo 30 GB) | 60 GB |
| Docker | 24 o superior | Última estable |
| SO | Linux (Debian, Red Hat, SUSE, Arch, Alpine, Raspberry Pi OS 64-bit) | Ubuntu 24.04 LTS o Debian 12 |

Los mínimos son de upstream; los recomendados son una decisión comercial de
Hefesto. Sobre Supabase: **no aplica**, el panel usa su propio PostgreSQL interno.

---

## Cosas que hay que decir antes de firmar

Este kit tiene tres límites que conviene no descubrir tarde. Están desarrollados
en [`docs/08-SERVICIOS-COMERCIALES.md`](docs/08-SERVICIOS-COMERCIALES.md).

**1. Coolify no es un proveedor de hosting.** El cliente aporta y paga el
servidor; Hefesto opera el panel y los despliegues. Si el cliente quiere que
Hefesto le venda el servidor, es otro producto.

**2. No es multi-tenant.** Una instancia administra los servidores de un cliente.
Si Hefesto opera muchos clientes en una instancia compartida, **cualquiera con
acceso administrativo ve los servidores de todos**. Eso no es un detalle
técnico: es una decisión de seguridad que debe estar escrita en el contrato. El
modelo defendible es una instancia dedicada por cliente.

**3. Respaldar el panel no respalda la aplicación.** El respaldo del kit cubre la
instancia del panel. Los datos de las apps del cliente necesitan su propio
respaldo, y si eso no está en el alcance comercial, hay que decirlo por escrito.

---

## Qué falta probar o configurar

Nada de esto se hizo; está en estado `kit preparado`:

- [ ] Instalación real con el script oficial en un servidor limpio.
- [ ] `post-instalacion.sh` contra una instancia viva.
- [ ] Un respaldo completo **verificado** con `sha256sum -c`.
- [ ] **Una restauración completa desde cero.** Un respaldo no probado no es un
      respaldo.
- [ ] Configuración del dominio con HTTPS y cierre de 8000/6001/6002.
- [ ] Comportamiento de `ufw` junto con las redes que crea Coolify.
- [ ] Actualización real desde el panel y por `upgrade.sh`.
- [ ] Habilitación de la API y alcance de un token de lectura.
- [ ] Verificación de si existe un interruptor global de registro cerrado.

Lista completa, con comandos: [`docs/07-PRUEBAS-DE-ACEPTACION.md`](docs/07-PRUEBAS-DE-ACEPTACION.md).

---

## Sobre la API

El kit **no usa la API** para instalar ni para respaldar: usa Docker y archivos.
La API de Coolify está documentada porque es la vía soportada para automatizar
operación, y porque el cliente puede preguntar por ella. Es un **uso real
documentado por upstream**, con token de alcance mínimo. Ver
[`docs/02-INSTALACION-COOLIFY.md`](docs/02-INSTALACION-COOLIFY.md), sección 6.

---

## Licencia

- Código y documentación de este kit: **Hefesto Studio**.
- Coolify: **Apache-2.0**, © coollabsio. <https://github.com/coollabsio/coolify>
- Detalle de cada componente:
  [`LICENCIAS.md`](LICENCIAS.md) y
  [`docs/10-LICENCIAS-Y-FUENTES.md`](docs/10-LICENCIAS-Y-FUENTES.md).
