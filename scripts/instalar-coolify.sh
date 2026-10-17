#!/usr/bin/env bash
# =============================================================================
# instalar-coolify.sh
# Hefesto Studio — Kit "VPS administrado Hefesto" (Coolify)
#
# QUE HACE
#   1. Revisa los prerrequisitos oficiales de Coolify en ESTE servidor.
#   2. Muestra, textualmente, el comando oficial de instalación.
#   3. Solo si el operador lo confirma de forma explícita, invoca el script
#      oficial de Coolify.
#
# QUE NO HACE (por diseño)
#   - No descarga ni ejecuta nada por su cuenta.
#   - No modifica el sistema mientras el operador no escriba la palabra de
#     confirmación.
#   - No repara ni actualiza una instancia existente: para eso está el flujo
#     de actualización documentado en docs/06-ACTUALIZACIONES-Y-REVERSION.md.
#
# ESTADO DEL KIT
#   Este script NO se ha ejecutado en un servidor real. El kit se entrega en
#   estado "kit preparado" (no había servidor ni Docker en el entorno de
#   desarrollo). Ver docs/07-PRUEBAS-DE-ACEPTACION.md.
#
# FUENTES
#   - Requisitos y SO soportado: https://coolify.io/docs/start-with-self-hosted
#   - Puertos:                https://coolify.io/docs/core/infrastructure/servers/firewall
#   - Script oficial:         https://cdn.coollabs.io/coolify/install.sh
#   - Version estable:        https://api.github.com/repos/coollabsio/coolify/releases/latest
# =============================================================================

set -euo pipefail

# --- Constantes verificadas -------------------------------------------------
COOLIFY_VERSION_VERIFICADA="v4.4.6"          # releases/latest, consultada 2026-10-16
CDN_URL="https://cdn.coollabs.io/coolify/install.sh"
COMANDO_OFICIAL="curl -fsSL ${CDN_URL} | bash"
DATA_DIR="/data/coolify"
ENV_FILE="${DATA_DIR}/source/.env"
PUERTO_DASHBOARD="8000"
MIN_DOCKER_MAJOR="24"                        # MIN_DOCKER_VERSION=24 en install.sh
DISCO_DOC_MIN_GB="10"                         # mínimo documentado (docs)
DISCO_TOTAL_MIN_GB="30"                      # aviso del instalador oficial
DISCO_LIBRE_MIN_GB="20"                      # aviso del instalador oficial
PALABRA_CONFIRMACION="INSTALAR"

# --- Opciones ----------------------------------------------------------------
MODO="revision"        # revision | instalar | solo-comando
DESCARGAR_PRIMERO="no" # si = "si", baja el script, muestra su SHA-256 y lo ejecuta
ASUME_SI="no"          # si = "si", no pide confirmación interactiva

# --- Presentación ------------------------------------------------------------
if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ] && [ -z "${NO_COLOR:-}" ]; then
  C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_BOLD=$'\033[1m'; C_OFF=$'\033[0m'
else
  C_OK=""; C_WARN=""; C_ERR=""; C_BOLD=""; C_OFF=""
fi

ERRORES=0
AVISOS=0

info()  { printf '%s\n' "$*"; }
titulo(){ printf '\n%s== %s ==%s\n' "$C_BOLD" "$*" "$C_OFF"; }
ok()    { printf '  %s[OK]%s %s\n' "$C_OK" "$C_OFF" "$*"; }
aviso() { printf '  %s[AVISO]%s %s\n' "$C_WARN" "$C_OFF" "$*"; AVISOS=$((AVISOS + 1)); }
error() { printf '  %s[ERROR]%s %s\n' "$C_ERR" "$C_OFF" "$*"; ERRORES=$((ERRORES + 1)); }

uso() {
  cat <<'EOF'
Uso: instalar-coolify.sh [opciones]

  --revision          Solo revisa prerrequisitos y muestra el comando oficial.
                      Es el modo por defecto. No modifica nada.
  --instalar          Revisa prerrequisitos y, si todo está en verde, pide
                      confirmación para invocar el script oficial.
  --solo-comando      Imprime el comando oficial de instalación y sale.
  --descargar-primero En vez de canalizar por curl|bash, descarga install.sh a
                      un archivo, muestra su SHA-256 y luego lo ejecuta.
  --si                No pide confirmación interactiva (para uso no attended).
                      Úsalo solo junto con --instalar y con conocimiento de
                      causa: equivale a aceptar la instalación.
  -h, --help          Muestra esta ayuda.

Códigos de salida
  0  todo correcto (o solo se imprimió el comando)
  1  hay errores de prerrequisitos: NO se instaló
  2  el operador canceló la instalación
EOF
}

# --- Parseo de argumentos ----------------------------------------------------
while [ "$#" -gt 0 ]; do
  case "$1" in
    --revision)          MODO="revision" ;;
    --instalar)          MODO="instalar" ;;
    --solo-comando)      MODO="solo-comando" ;;
    --descargar-primero) DESCARGAR_PRIMERO="si" ;;
    --si)                ASUME_SI="si" ;;
    -h|--help)           uso; exit 0 ;;
    *) printf 'Opción desconocida: %s\n\n' "$1" >&2; uso >&2; exit 1 ;;
  esac
  shift
done

if [ "$MODO" = "solo-comando" ]; then
  info "$COMANDO_OFICIAL"
  exit 0
fi

# =============================================================================
# Prerrequisitos
# =============================================================================
titulo "Prerrequisitos"

# 1. Privilegios root --------------------------------------------------------
if [ "$(id -u)" -eq 0 ]; then
  ok "Ejecutando como root."
else
  error "Se requiere root. El instalador oficial aborta si no es root."
fi

# 2. Sistema Linux -----------------------------------------------------------
if [ "$(uname -s)" = "Linux" ]; then
  ok "Sistema operativo Linux ($(uname -r))."
else
  error "Coolify solo corre en Linux. Detectado: $(uname -s)."
fi

# 3. Familia de sistema operativo soportada ---------------------------------
# Fuente: https://coolify.io/docs/start-with-self-hosted (tabla de SO soportado)
# Se leen los datos una sola vez para no repetir el "source" de /etc/os-release.
OS_ID="$( . /etc/os-release 2>/dev/null && echo "${ID:-desconocido}" )"
OS_VERSION_ID="$( . /etc/os-release 2>/dev/null && echo "${VERSION_ID:-}" )"
OS_CODENAME="$( . /etc/os-release 2>/dev/null && echo "${VERSION_CODENAME:-}" )"

case "$OS_ID" in
  debian|ubuntu)
    ok "Familia Debian/Ubuntu: soportada (${OS_ID} ${OS_VERSION_ID})."
    case "$OS_CODENAME" in
      focal|jammy|noble)
        ok "Ubuntu LTS (${OS_CODENAME}), la recomendada por upstream."
        ;;
      *)
        aviso "Esta versión de Ubuntu no es LTS. Upstream recomienda una LTS (20.04, 22.04, 24.04) y Evita no-LTS."
        ;;
    esac
    ;;
  raspbian)
    ok "Raspberry Pi OS (64-bit): soportada. Verifica que la imagen sea de 64 bits."
    ;;
  centos|fedora|rhel|ol|rocky|almalinux|amzn|tencentos|asahi)
    ok "Familia Red Hat: soportada."
    ;;
  sles|opensuse|opensuse-leap|opensuse-tumbleweed)
    ok "Familia SUSE: soportada."
    ;;
  arch|archarm|manjaro)
    ok "Familia Arch: soportada."
    ;;
  alpine)
    ok "Familia Alpine: soportada."
    ;;
  postmarketos)
    aviso "postmarketOS no aparece en la tabla oficial de la documentación. Verifica en la versión vigente de https://coolify.io/docs/start-with-self-hosted."
    ;;
  *)
    aviso "Familia '${ID:-desconocida}' no figura en la tabla oficial de SO soportado. Revisa https://coolify.io/docs/start-with-self-hosted antes de continuar."
    ;;
esac

# 4. Recursos del servidor ---------------------------------------------------
CPU_MODELOS=$(nproc 2>/dev/null || echo "?")
MEM_GB=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo "?")
DISCO_TOTAL_GB=$(df -BG / 2>/dev/null | awk 'NR==2 {gsub("G","",$2); print $2}')
DISCO_LIBRE_GB=$(df -BG / 2>/dev/null | awk 'NR==2 {gsub("G","",$4); print $4}')

info "  CPU: ${CPU_MODELOS} vCPU | RAM: ${MEM_GB} GB | Disco /: ${DISCO_TOTAL_GB} GB totales, ${DISCO_LIBRE_GB} GB libres"

if [ "${CPU_MODELOS}" != "?" ] && [ "$CPU_MODELOS" -lt 2 ]; then
  aviso "La documentación pide 2 vCPU como mínimo (recomendado). Con ${CPU_MODELOS} vCPU la instancia y las apps convivirán justas."
else
  ok "vCPU suficientes para el mínimo documentado (2 vCPU)."
fi

if [ "${MEM_GB}" != "?" ] && [ "$MEM_GB" -lt 2 ]; then
  aviso "La documentación pide 2 GB de RAM como mínimo. Aquí hay ${MEM_GB} GB."
else
  ok "RAM suficiente para el mínimo documentado (2 GB)."
fi

if [ "${DISCO_TOTAL_GB:-0}" -ge "$DISCO_TOTAL_MIN_GB" ]; then
  ok "Disco total >= ${DISCO_TOTAL_MIN_GB} GB (umbral de aviso del instalador oficial)."
else
  aviso "Disco total: ${DISCO_TOTAL_GB} GB. El instalador oficial avisa por debajo de ${DISCO_TOTAL_MIN_GB} GB (mínimo documentado: ${DISCO_DOC_MIN_GB} GB)."
fi

if [ "${DISCO_LIBRE_GB:-0}" -lt "$DISCO_LIBRE_MIN_GB" ]; then
  aviso "Disco libre: ${DISCO_LIBRE_GB} GB. El instalador oficial pide >= ${DISCO_LIBRE_MIN_GB} GB libres."
fi

# 5. Docker ------------------------------------------------------------------
if command -v docker >/dev/null 2>&1; then
  DOCKER_MAJOR=$(docker version --format '{{.Server.Version}}' 2>/dev/null | cut -d. -f1 || true)
  if [ -z "$DOCKER_MAJOR" ]; then
    aviso "Docker está instalado pero no se pudo obtener la versión del servidor Docker (¿falta permiso en /var/run/docker.sock o el daemon no corre?)."
  elif [ "$DOCKER_MAJOR" -lt "$MIN_DOCKER_MAJOR" ]; then
    error "Docker ${DOCKER_MAJOR} es demasiado antiguo. Coolify exige Docker ${MIN_DOCKER_MAJOR} o superior (MIN_DOCKER_VERSION=24 en install.sh)."
  else
    ok "Docker ${DOCKER_MAJOR} (mínimo ${MIN_DOCKER_MAJOR})."
  fi

  if [ -d /snap ] && docker --version 2>/dev/null | grep -qi snap; then
    error "El instalador oficial no soporta Docker instalado por snap. Reinstala Docker con el método oficial de Docker Engine."
  fi
else
  error "Docker no está instalado. Instálalo antes de continuar (ver docs/01-INSTALACION-DOCKER.md)."
fi

# 6. Herramientas necesarias -------------------------------------------------
for BIN in curl tar; do
  if command -v "$BIN" >/dev/null 2>&1; then
    ok "Herramienta presente: ${BIN}."
  else
    error "Falta la herramienta requerida: ${BIN}."
  fi
done

# 7. Puertos -----------------------------------------------------------------
titulo "Puertos"
info "  Tabla oficial (https://coolify.io/docs/core/infrastructure/servers/firewall):"
info "    22/tcp   acceso SSH (salvo que configures otro puerto SSH)"
info "    80/tcp   tráfico HTTP y emisión de certificados vía el proxy"
info "    443/tcp  tráfico HTTPS vía el proxy"
info "    8000/tcp acceso directo al panel en http://<ip-del-servidor>:8000"
info "    6001/tcp actualizaciones en tiempo real del panel (acceso por IP)"
info "    6002/tcp terminal web del panel (acceso por IP)"
info "  Tras poner el panel tras un dominio con el proxy, upstream indica que"
info "  8000, 6001 y 6002 pueden cerrarse al público."

if command -v ss >/dev/null 2>&1; then
  if ss -lnt 2>/dev/null | grep -q ":${PUERTO_DASHBOARD}[[:space:]]"; then
    aviso "El puerto ${PUERTO_DASHBOARD} ya está en uso. Puede ser otro proceso o una instancia anterior."
  else
    ok "Puerto ${PUERTO_DASHBOARD} libre."
  fi
else
  aviso "No se encontró 'ss'; no se pudo comprobar el puerto ${PUERTO_DASHBOARD}."
fi

# 8. Estado previo de la instancia -------------------------------------------
titulo "Estado previo"
if [ -d "$DATA_DIR" ]; then
  error "${DATA_DIR} ya existe. Esto parece una instalación existente: usa el flujo de actualización (docs/06-ACTUALIZACIONES-Y-REVERSION.md), no la instalación."
else
  ok "${DATA_DIR} no existe: corresponde a una instalación nueva."
fi

# --- Resumen -----------------------------------------------------------------
titulo "Resumen"
info "  Errores: ${ERRORES} | Avisos: ${AVISOS}"
info "  Versión estable verificada de Coolify: ${COOLIFY_VERSION_VERIFICADA}"
info "  Comando oficial de instalación:"
info "      ${COMANDO_OFICIAL}"

if [ "$ERRORES" -gt 0 ]; then
  info ""
  error "No se continúa: hay ${ERRORES} error(es) de prerrequisito."
  exit 1
fi

if [ "$MODO" = "revision" ]; then
  info ""
  info "Modo revisión: no se instaló nada."
  info "Para instalar, vuelve a ejecutar con:  sudo ./instalar-coolify.sh --instalar"
  exit 0
fi

# =============================================================================
# Confirmación del operador
# =============================================================================
if [ "$ASUME_SI" != "si" ]; then
  if [ ! -t 0 ]; then
    error "No hay terminal para pedir confirmación. Revisa los requisitos y usa --si solo si aceptas instalar."
    exit 2
  fi
  info ""
  printf '  Se va a ejecutar el script oficial de Coolify (%s).\n' "$COOLIFY_VERSION_VERIFICADA"
  printf '  Escribe exactamente %s para continuar: ' "$PALABRA_CONFIRMACION"
  RESPUESTA=""
  read -r RESPUESTA || true
  if [ "$RESPUESTA" != "$PALABRA_CONFIRMACION" ]; then
    info "Cancelado. No se instaló nada."
    exit 2
  fi
fi

# =============================================================================
# Invocación del script oficial
# =============================================================================
info ""
info "Delegando en el instalador oficial de Coolify..."

if [ "$DESCARGAR_PRIMERO" = "si" ]; then
  SCRIPT_LOCAL="$(mktemp /tmp/coolify-install-XXXXXX.sh)"
  # shellcheck disable=SC2064
  trap "rm -f '$SCRIPT_LOCAL'" EXIT
  if ! curl -fsSL "$CDN_URL" -o "$SCRIPT_LOCAL"; then
    error "No se pudo descargar ${CDN_URL}"
    exit 1
  fi
  info "Script oficial descargado en: ${SCRIPT_LOCAL}"
  info "SHA-256 (anótalo en tu bitácora de cambios):"
  sha256sum "$SCRIPT_LOCAL" || true
  info "Ejecutando ese archivo descargado..."
  bash "$SCRIPT_LOCAL"
else
  # Forma oficial documentada por upstream.
  eval "$COMANDO_OFICIAL"
fi

# --- Cierre ------------------------------------------------------------------
info ""
ok "El instalador oficial terminó. Verifica con:"
info "      ./post-instalacion.sh"
info "Y respalda ${ENV_FILE} apenas termines."
