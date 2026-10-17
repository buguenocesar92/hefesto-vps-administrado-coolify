# 01 — Instalación de Docker

Coolify necesita Docker Engine en el servidor. Este documento cubre esa parte
**por separado**, porque en un VPS nuevo es el primer paso y porque sirve
también para diagnosticar una instalación mala.

> **Este documento es de Hefesto.** La instalación del panel en sí está en
> [`02-INSTALACION-COOLIFY.md`](02-INSTALACION-COOLIFY.md). El orden correcto es
> Docker primero, Coolify después.

---

## 1. Requisitos del servidor

Coolify documenta estos mínimos para **el panel**:

| Recurso | Mínimo documentado |
|---|---|
| CPU | 2 vCPU |
| RAM | 2 GB |
| Disco | 10 GB |

Fuente: <https://coolify.io/docs/start-with-self-hosted>

**Importante:** esos números son para el panel **solo**. Si en el mismo servidor
van a correr las aplicaciones del cliente, el cálculo real es otro: hay que sumar
la app, su base de datos y el margen. Un VPS de 2 GB con el panel encima **no**
alberga una aplicación de producción.

Hay una segunda cifra en juego, más exigente: el instalador oficial **avisa** por
debajo de 30 GB de disco total y pide al menos 20 GB libres
(`REQUIRED_TOTAL_SPACE=30` y `REQUIRED_AVAILABLE_SPACE=20` en
<https://cdn.coollabs.io/coolify/install.sh>). Si vendes el panel, cita las dos
cifras y di de dónde sale cada una: el mínimo documentado y el umbral del
instalador.

**Recomendación de Hefesto para el producto comercial:** mínimo 4 vCPU / 8 GB
RAM / 60 GB de disco para panel + una aplicación real. Es una decisión comercial
nuestra, no un requisito de upstream.

---

## 2. Sistema operativo

Coolify es **solo Linux**. La documentación oficial marca como soportadas estas
familias:

| Familia | Ejemplos | Notas |
|---|---|---|
| Debian | Debian, Ubuntu | En Ubuntu se recomienda una **LTS** (20.04, 22.04, 24.04) |
| Red Hat | CentOS, Fedora, RHEL, AlmaLinux, Rocky, Oracle, Amazon Linux, TencentOS | |
| SUSE | SLES, openSUSE | |
| Arch | Arch Linux | |
| Alpine | Alpine Linux | |
| Raspberry Pi OS | Raspberry Pi OS 64-bit | Solo imagen de 64 bits |

Fuente: <https://coolify.io/docs/start-with-self-hosted>

**No usar Ubuntu no-LTS.** Upstream lo dice explícitamente: la instalación
automática no está pensada para esas versiones.

---

## 3. Instalación de Docker Engine en Debian/Ubuntu

Estos son los comandos del repositorio oficial de Docker, no de Hefesto.
Fuente: <https://docs.docker.com/engine/install/ubuntu/>

```bash
# 0. Partir de un servidor limpio. Esta guía asume una instalación nueva.
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# 1. Repositorio oficial de Docker (NO el paquete 'docker.io' de Ubuntu)
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# 2. Versión instalada
sudo docker version
```

### 3.1 El error más común: Docker instalado por snap

**No instales Docker por snap.** El instalador oficial de Coolify lo rechaza
explícitamente. Si ya está instalado, desinstálalo y usa el repositorio de
Docker de arriba.

```bash
# Verificar de dónde viene Docker
docker --version
```

Si en la salida aparece `snap`, rehaz la instalación.

### 3.2 Verificar el requisito de versión

Coolify exige **Docker 24 o superior** (`MIN_DOCKER_VERSION=24` en el script de
instalación oficial).

```bash
docker version --format '{{.Server.Version}}'
```

Si la versión mayor es menor que 24, actualiza Docker **antes** de instalar
Coolify.

---

## 4. Puertos que hay que abrir

Coolify documenta esta tabla de puertos
(<https://coolify.io/docs/core/infrastructure/servers/firewall>):

| Puerto | Para qué |
|---|---|
| `22/tcp` | Acceso SSH (salvo que configures otro puerto SSH) |
| `80/tcp` | Tráfico HTTP y emisión de certificados por el proxy |
| `443/tcp` | Tráfico HTTPS por el proxy |
| `8000/tcp` | Acceso directo al panel en `http://<ip-del-servidor>:8000` |
| `6001/tcp` | Actualizaciones en tiempo real del panel (acceso por IP) |
| `6002/tcp` | Terminal web del panel (acceso por IP) |

**Advertencia de upstream:** no quites la regla de SSH mientras configuras el
firewall; una regla mal puesta deja fuera del servidor.

Y algo importante para la operación: **una vez que el panel funcione por un
dominio a través del proxy, se pueden cerrar `8000`, `6001` y `6002` al
público**. El panel, las actualizaciones en tiempo real y la terminal pasan a
usar 80 y 443.

Ejemplo con UFW (opcional; el kit no lo impone):

```bash
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8000/tcp    # temporal, hasta que el panel tenga dominio
sudo ufw enable
```

> `ufw` interfiere con las reglas de Docker. Si el cliente usa UFW, hay que
> revisarlo junto con las redes que crea Coolify. Ver
> `docs/02-INSTALACION-COOLIFY.md`.

---

## 5. Verificación final de esta etapa

```bash
sudo docker version           # debe existir salida "Server:"
sudo docker run --rm hello-world
sudo docker compose version   # el plugin de Compose
```

Si los tres responden, la etapa de Docker está lista. Sigue con
[`02-INSTALACION-COOLIFY.md`](02-INSTALACION-COOLIFY.md).

---

## 6. Diferencia con Coolify (resumen)

| | `docker compose` normal | Coolify |
|---|---|---|
| Qué levanta | Lo que tú escribas | El panel y las apps que el cliente defina |
| Quién decide el TLS | Tú | Coolify, con su proxy |
| Quién abre los puertos | Tú | Coolify, según el dominio configurado |
| Datos persistentes | Los volúmenes que declares | `/data/coolify` más los volúmenes de cada recurso |
| Límite de recursos | El que escribas | A definir por el cliente |

Un servidor puede usar **ambos**: Coolify para el panel y aplicaciones
gestionadas, y `docker compose` manual para algo puntual. Ver
`docs/02-INSTALACION-COOLIFY.md`, sección "Coolify dentro de Coolify".

---

## 7. Pendiente de verificación

- No se ejecutó esta instalación en un servidor real. No hay servidor ni Docker
  en el entorno donde se escribió el kit. Ver
  [`07-PRUEBAS-DE-ACEPTACION.md`](07-PRUEBAS-DE-ACEPTACION.md).
- No se probó `ufw` junto con las redes que crea Coolify. Debe probarse en el
  servidor del cliente antes de activar el firewall.
