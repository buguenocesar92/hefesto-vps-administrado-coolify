# 02 — Instalación de Coolify

Este documento es el paso central del kit: instalar el panel en un VPS y dejarlo
listo para operar.

---

## 1. Por qué este kit NO trae un `compose.yaml` para el panel

Coolify **no se instala con un `docker compose` propio**. Se instala con un
script oficial que descarga su propio compose, genera sus secretos y levanta sus
propios contenedores:

```bash
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
```

Fuente: <https://coolify.io/docs/start-with-self-hosted>

Si escribiéramos un `compose.yaml` "de Coolify" estaríamos haciendo una de dos
cosas malas:

1. **Duplicando el compose oficial sin entenderlo**, y quedando desincronizado
   con cada versión.
2. **Invitando a romperlo**, porque el script oficial además genera el `.env`
   con `APP_KEY`, `DB_PASSWORD`, `REDIS_PASSWORD`, `APP_ID` y las claves de
   Pusher, crea la red `coolify` y aplica permisos que el contenedor espera.

Por eso **este kit no incluye un `compose.yaml` en la raíz**. No es un
problema del kit: es cómo se instala Coolify.

**Lo que sí trae el kit:**

| Necesidad | Qué se usa |
|---|---|
| Instalar el panel | El script oficial de Coolify |
| Operar el panel | La API de Coolify (ver sección 6 de este documento) |
| Respaldar la instancia | `scripts/backup-coolify.sh` (de Hefesto) |
| Restaurar | `scripts/restore-coolify.sh` (de Hefesto) |
| Mostrar a un cliente una app dentro de Coolify | `ejemplos/compose-aplicacion-ejemplo.yaml`, **marcado como demostración** |

---

## 2. Requisitos (verificados)

| Requisito | Valor | Fuente |
|---|---|---|
| Sistema | Solo Linux; familias Debian, Red Hat, SUSE, Arch, Alpine y Raspberry Pi OS 64-bit | [docs](https://coolify.io/docs/start-with-self-hosted) |
| CPU | 2 vCPU mínimo documentado | [docs](https://coolify.io/docs/start-with-self-hosted) |
| RAM | 2 GB mínimo documentado | [docs](https://coolify.io/docs/start-with-self-hosted) |
| Disco | 10 GB mínimo documentado; el instalador avisa bajo 30 GB totales | [docs](https://coolify.io/docs/start-with-self-hosted) / [`install.sh`](https://cdn.coollabs.io/coolify/install.sh) |
| Docker | 24 o superior | `MIN_DOCKER_VERSION=24` en [`install.sh`](https://cdn.coollabs.io/coolify/install.sh) |
| Privilegios | root (`sudo`) | `install.sh` aborta si no es root |
| Puertos | 22, 80, 443 abiertos; 8000, 6001, 6002 para acceso directo | [docs](https://coolify.io/docs/core/infrastructure/servers/firewall) |

Prepara antes Docker: [`01-INSTALACION-DOCKER.md`](01-INSTALACION-DOCKER.md).

---

## 3. Instalación

### 3.1 Opción A — con el verificador del kit (recomendado para Hefesto)

El script de Hefesto revisa prerrequisitos y **no ejecuta nada** hasta que el
operador lo confirma:

```bash
# 1. Solo revisar. No modifica nada.
sudo ./scripts/instalar-coolify.sh --revision

# 2. Si todo está en verde, instalar (pide escribir INSTALAR).
sudo ./scripts/instalar-coolify.sh --instalar
```

Opciones útiles:

- `--descargar-primero`: en vez de canalizar por `curl | bash`, descarga el
  script, **imprime su SHA-256** y lo ejecuta. Deja registro criptográfico de
  qué se ejecutó.
- `--solo-comando`: solo imprime el comando oficial.
- `--si`: acepta la instalación sin pregunta. **No usar** en la primera
  instalación.

### 3.2 Opción B — el comando oficial, tal cual

Si prefieres el camino de upstream, sin intermediarios:

```bash
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
```

El script oficial no es interactivo al final: genera credenciales, las imprime
en la salida y ahí se acaban. **Cópialas a un lugar seguro antes de cerrar la
terminal.**

### 3.3 Qué hace el instalador (verificado leyendo `install.sh`)

No es un misterio: se leyó el script oficial completo. Hace, entre otras cosas:

1. Verifica root, espacio en disco y versión de Docker (`MIN_DOCKER_VERSION=24`).
2. Crea `/data/coolify` y las subcarpetas `source/`, `images/`,
   `ssh/keys/`, `ssh/mux/`.
3. Aplica permisos al estilo del instalador oficial:
   `chown -R 9999:root` y `chmod -R 700` sobre `source`, `ssh` e `images`.
4. Genera secretos en **`/data/coolify/source/.env`**: `APP_KEY`,
   `DB_PASSWORD`, `REDIS_PASSWORD`, `APP_ID`, `PUSHER_APP_ID`,
   `PUSHER_APP_KEY`, `PUSHER_APP_SECRET`.
5. Define un usuario inicial (`ROOT_USERNAME`, `ROOT_USER_EMAIL`,
   `ROOT_USER_PASSWORD`).
6. Crea la red `coolify`.
7. Descarga a `/data/coolify/source/`: `docker-compose.yml`,
   `docker-compose.prod.yml`, `.env.production`, `upgrade.sh` y
   `upgrade-postgres.sh`.
8. Levanta los contenedores y espera a que el contenedor `coolify` quede en
   estado **`healthy`**.

**Estos datos son el corazón del kit de respaldo.** Todo lo que Coolify sabe de
la instancia vive bajo `/data/coolify`, y los secretos de instalación, en
`/data/coolify/source/.env`. Upstream dice sin rodeos: respalda ese `.env` justo
después de instalar.

### 3.4 Contenedores resultantes

Del `docker-compose` oficial (<https://cdn.coollabs.io/coolify/docker-compose.yml>
y <https://cdn.coollabs.io/coolify/docker-compose.prod.yml>):

| Contenedor | Imagen | Función |
|---|---|---|
| `coolify` | `coollabsio/coolify` | El panel (Laravel) |
| `coolify-db` | `postgres:15-alpine` | Base de datos interna del panel |
| `coolify-redis` | `redis:7-alpine` | Caché y colas internas |
| `coolify-proxy` | la que resuelva el panel (Traefik) | Proxy inverso; lo crea el panel al configurar un proxy |

Sobre Supabase: **no aplica.** El panel usa su propio PostgreSQL interno
(`coolify-db`). No hay nada que conectar a Supabase ni que evaluar.

El healthcheck que usa el propio compose oficial es:

```
curl --fail http://127.0.0.1:8080/api/health && curl --fail http://127.0.0.1:${PUSHER_BACKEND_PORT}/up
```

---

## 4. Verificación posterior

```bash
sudo ./scripts/post-instalacion.sh
```

El script **solo lee**. Revisa contenedores, healthcheck, puerto 8000,
respuesta de `/api/health`, existencia y permisos de
`/data/coolify/source/.env`, presencia del `APP_KEY` y versión de la imagen.

Después, a mano:

```bash
# El panel debería responder
curl -fsS http://127.0.0.1:8000/api/health

# Y ser accesible desde fuera
curl -fsS http://<IP-DEL-SERVIDOR>:8000/api/health
```

---

## 5. El dominio y HTTPS del panel

Este es el paso que convierte un panel expuesto en `:8000` en un panel serio.

### 5.1 Qué hacer en el panel

1. Entra al panel con la cuenta inicial.
2. Ve a **Settings** (en la barra lateral izquierda).
3. Configura el campo de **URL de la instancia** con la URL completa del panel,
   por ejemplo `https://coolify.ejemplo.cl`.
4. El DNS de ese dominio debe apuntar al servidor donde corre Coolify.
5. Activa **redirección de HTTP a HTTPS**.
6. Guarda los cambios.

Upstream advierte además de dos cosas: si la URL de la instancia ya está en uso
por otro recurso, Coolify lo avisa; y si choca con el dominio de otro recurso,
los certificados y el ruteo se vuelven impredecibles.

Fuente: <https://coolify.io/docs/core/instance-management/instance-settings>

### 5.2 Qué pasa con los puertos 8000, 6001 y 6002

Texto de upstream, en la página de puertos:

> "After the dashboard works through a domain using the Coolify proxy, you can
> close public access to ports 8000, 6001, and 6002. The dashboard, real-time
> connection, and terminal will use ports 80 and 443 through the proxy."

Traducción operativa: **cuando el panel ya responda por su dominio en 443, cierra
`8000`, `6001` y `6002` al público.** El panel, las actualizaciones en tiempo
real y la terminal web pasan a viajar por 80 y 443.

El orden correcto es:

1. Verificar que `https://coolify.ejemplo.cl` carga y que el certificado es válido.
2. Verificar que el terminal web y las actualizaciones en vivo siguen funcionando.
3. **Recién entonces** cerrar `8000`, `6001`, `6002`.

No cierres nada antes de verificar el paso 1. Un panel sin acceso directo y sin
dominio funcionando es un servidor inaccesible.

### 5.3 Sobre el firewall

Coolify administra rutas de red y un proxy. Un `ufw` mal configurado puede cortar
el tráfico del proxy o de las apps que Coolify despliega. Si el cliente quiere
firewall, hay que configurarlo **después** de tener el proxy funcionando y
probando el resultado. Este kit no incluye una receta de firewall aplicada
automáticamente.

---

## 6. La API de Coolify

**Uso real documentado por upstream.** El kit no depende de la API para
instalar ni para respaldar, pero es la vía soportada para automatizar operación.

- **Base:** `https://coolify.io/docs/api/`
- **Prefijo:** las rutas se registran bajo `/api` y las versionadas bajo
  `/api/v1/...` (verificado en `app/Providers/RouteServiceProvider.php` y
  `routes/api.php` del repositorio).
- **Autenticación:** encabezado `Authorization: Bearer <api-token>`.
- **Formato del token:** `<id>|<secreto>`, tal como lo muestra el panel al
  crearlo. Hay que enviarlo completo.
- **Ejemplo oficial:**
  ```bash
  curl --header "Authorization: Bearer $COOLIFY_TOKEN" \
       "$COOLIFY_URL/api/v1/teams/current"
  ```
- **Permisos del token:** la documentación incluye `read`, `write`,
  `read:sensitive` y `root`. En el código, las rutas sensibles exigen además
  `auth:sanctum`, validación de equipo y el permiso `api.sensitive`.
- **La API debe estar habilitada** en la instancia; si no, el middleware la
  rechaza.
- **Endpoints útiles verificados:** `GET /api/v1/version` (requiere `read`),
  `GET /api/health` y `GET /api/v1/health` (sin token).

Fuentes: <https://coolify.io/docs/api/authorization> y el código en
`https://github.com/coollabsio/coolify` (rama `v4.x`).

**Lo que este kit SÍ hace con la API:** nada. Los scripts usan Docker y
archivos, no la API. La API queda documentada para que Hefesto la use en
automatizaciones propias, con un token de alcance mínimo.

**Precauciones para un token:** es una credencial equivalente a acceso al panel.
No la pongas en `.env` versionado, no la pegues en tickets, y rótala si alguien
la ve.

---

## 7. Coolify dentro de Coolify

Sí: **una instancia de Coolify puede ser un recurso gestionado por otra
instancia de Coolify.** Suena raro y sin embargo tiene sentido real. Vale la
pena entenderlo antes de decidir la arquitectura del servicio.

### 7.1 Qué significa en la práctica

En Coolify, un recurso "Docker Compose" es un YAML que Coolify despliega y opera:
construye la imagen si hace falta, levanta el contenedor, lo reinicia, aplica el
dominio y emite el TLS. Como el panel de Coolify **es** un conjunto de
contenedores con un compose, técnicamente se puede entregar a otro panel como un
recurso más.

### 7.2 Por qué tiene sentido

**Razón A — un punto único de control.** Si el cliente tiene varios VPS, puede
tener un panel "principal" que despliegue y supervise los demás servidores,
incluidos los paneles secundarios. Desde una sola consola se ve todo.

**Razón B — separar panel y aplicaciones.** Es el patrón más útil en operación
real: el panel va en un servidor chico y estable, y las aplicaciones en
servidores más grandes. Un panel que se cae no se lleva por delante las apps, y
un servidor de aplicación que hay que reiniciar no interrumpe el panel.

**Razón C — homogeneidad de operación.** Si Hefesto opera todo con la misma
herramienta, los procedimientos son los mismos para el panel y para las apps:
mismos respaldos, misma bitácora, misma forma de recuperar.

### 7.3 Por qué hay que pensarlo dos veces

- **El panel deja de ser "del cliente" y pasa a ser un recurso desplegable.**
  Si alguien redeploya el recurso del panel, se actualiza a sí mismo. Conviene
  que eso no sea un clic de cualquiera.
- **Los respaldos se anidan.** Si el respaldo del panel está dentro de un
  servidor que administra el panel, se vuelve frágil si el panel cae. La
  outermost debe vivir fuera.
- **Actualizar el panel es una operación sobre el recurso que lo administra.**
  Puede quedar a medias. Conviene tener el `upgrade.sh` documentado para hacer
  la actualización por la vía soportada.

### 7.4 Recomendación de Hefesto

**No anidar por omisión.** Instalar el panel directamente en el servidor con el
script oficial (sección 3) es el camino más simple y el más fácil de recuperar.
Si el cliente tiene varios servidores, la separación útil es otra: **un panel,
varios servidores de aplicaciones**, no un panel dentro de otro panel.

Si aun así se decide anidar, hay que documentarlo en la bitácora del cliente
con: qué panel administra a cuál, dónde viven los respaldos de cada uno, y quién
puede redeployar el recurso del panel.

---

## 8. Estado

**kit preparado.** No se instaló Coolify en ningún servidor: en el entorno donde
se escribió el kit no hay servidor ni Docker. Todo lo verificado en este
documento proviene de leer la documentación oficial y el código del
instalador, no de una instalación ejecutada. Ver
[`07-PRUEBAS-DE-ACEPTACION.md`](07-PRUEBAS-DE-ACEPTACION.md).
