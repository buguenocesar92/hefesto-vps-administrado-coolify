#!/usr/bin/env bash
# =============================================================================
# post-instalacion.sh
# Hefesto Studio — Kit "VPS administrado Hefesto" (Coolify)
#
# QUE HACE
#   Verificación posterior a la instalación (o a una restauración). SOLO LEE:
#   no detiene nada, no modifica permisos y no cambia configuración.
#
#   Revisa:
#     1. Estado de los contenedores de Coolify.
#     2. El healthcheck del contenedor 'coolify' (upstream exige 'healthy').
#     3. Que el puerto 8000 esté escuchando y que /api/health responda.
#     4. Que /data/coolify/source/.env exista con los permisos correctos.
#     5. La versión de la imagen del panel.
#     6. Los puertos que deberían estar abiertos.
#     7. Recordatorio de respaldar el .env (APP_KEY) apenas terminado.
#
# ESTADO DEL KIT
#   Este script NO se ha ejecutado en un servidor real. El kit se entrega en
#   estado "kit preparado". Ver docs/07-PRUEBAS-DE-ACEPTACION.md.
#
# FUENTES
#   - Healthcheck usado por el propio instalador oficial y rutas del panel:
#     https://cdn.coollabs.io/coolify/install.sh (docker-compose.prod.yml)
#     https://coolify.io/docs/start-with-self-hosted
#   - Tabla de puertos:
#     https://coolify.io/docs/core/infrastructure/servers/firewall
#   - APP_KEY:
#     https://coolify.io/docs/core/backup-and-recovery/instance-backup
# =============================================================================

set -euo pipefail

# --- Configuración -----------------------------------------------------------
DATA_DIR="${COOLIFY_DATA_DIR:-/data/coolify}"
ENV_FILE="${DATA_DIR}/source/.env"
PUERTO_DASHBOARD="8000"
PUERTO_REALTIME="6001"
PUERTO_TERMINAL="6002"
CONT_COOLIFY="coolify"
CONT_DB="coolify-db"
CONT_REDIS="coolify-redis"
CONT_PROXY="coolify-proxy"
VERSION_ESPERADA="v4.4.6"

# --- Presentación ------------------------------------------------------------
if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ] && [ -z "${NO_COLOR:-}" ]; then
  C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_BOLD=$'\033[1m'; C_OFF=$'\033[0m'
else
  C_OK=""; C_WARN=""; C_ERR=""; C_BOLD=""; C_OFF=""
fi

PROBLEMAS=0
AVISOS=0

info()   { printf '%s\n' "$*"; }
titulo() { printf '\n%s== %s ==%s\n' "$C_BOLD" "$*" "$C_OFF"; }
ok()     { printf '  %s[OK]%s %s\n' "$C_OK" "$C_OFF" "$*"; }
aviso()  { printf '  %s[AVISO]%s %s\n' "$C_WARN" "$C_OFF" "$*"; AVISOS=$((AVISOS + 1)); }
error()  { printf '  %s[ERROR]%s %s\n' "$C_ERR" "$C_OFF" "$*"; PROBLEMAS=$((PROBLEMAS + 1)); }

contenedor_existe()    { docker inspect "$1" >/dev/null 2>&1; }
contenedor_corriendo() { [ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null || echo false)" = "true" ]; }

# =============================================================================
# 1. Entorno mínimo
# =============================================================================
titulo "Entorno"

if [ "$(id -u)" -ne 0 ]; then
  aviso "No eres root: puede que no puedas ver todos los contenedores ni los secretos. Se recomienda root."
else
  ok "Ejecutando como root."
fi

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  ok "Docker disponible ($(docker version --format '{{.Server.Version}}' 2>/dev/null || echo '?'))"
else
  error "Docker no disponible. Si acabas de instalar Coolify, esto es un problema."
fi

# =============================================================================
# 2. Contenedores
# =============================================================================
titulo "Contenedores"

# coolify-proxy lo crea el panel cuando se configura el proxy de un servidor:
# puede no existir todavía y eso es normal en una instalación recién hecha.
for CONT in "$CONT_COOLIFY" "$CONT_DB" "$CONT_REDIS" "$CONT_PROXY"; do
  if ! contenedor_existe "$CONT"; then
    if [ "$CONT" = "$CONT_PROXY" ]; then
      aviso "${CONT} no existe todavía. Es normal: el proxy se crea al configurar el proxy de un servidor."
    else
      error "${CONT} no existe."
    fi
    continue
  fi

  if contenedor_corriendo "$CONT"; then
    ok "${CONT} está corriendo."
  else
    error "${CONT} existe pero está detenido."
  fi
done

# Healthcheck: el instalador oficial espera que el contenedor 'coolify' quede
# en estado 'healthy'.
if contenedor_existe "$CONT_COOLIFY"; then
  SALUD="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}sin-healthcheck{{end}}' "$CONT_COOLIFY" 2>/dev/null || echo desconocido)"
  case "$SALUD" in
    healthy)       ok "Healthcheck de ${CONT_COOLIFY}: healthy." ;;
    starting)      aviso "Healthcheck de ${CONT_COOLIFY}: starting. Espera unos segundos y vuelve a correr este script." ;;
    sin-healthcheck) aviso "El contenedor ${CONT_COOLIFY} no tiene healthcheck definido." ;;
    *)             error "Healthcheck de ${CONT_COOLIFY}: ${SALUD}." ;;
  esac
fi

# =============================================================================
# 3. Versión
# =============================================================================
titulo "Versión"

if contenedor_existe "$CONT_COOLIFY"; then
  IMAGEN="$(docker inspect -f '{{.Config.Image}}' "$CONT_COOLIFY" 2>/dev/null || echo desconocido)"
  info "  Imagen del panel: ${IMAGEN}"
  if printf '%s' "$IMAGEN" | grep -q "${VERSION_ESPERADA#v}"; then
    ok "Coincide con la versión estable verificada por el kit (${VERSION_ESPERADA})."
  elif printf '%s' "$IMAGEN" | grep -q ':latest'; then
    aviso "La imagen usa la etiqueta 'latest'. Para operación controlada conviene fijar una versión."
  else
    aviso "La imagen no es la versión ${VERSION_ESPERADA} verificada por el kit. Revisa /docs/core/instance-management/update."
  fi
fi

# =============================================================================
# 4. Puertos y panel
# =============================================================================
titulo "Panel web"

ESCUCHA_8000="no"
if command -v ss >/dev/null 2>&1; then
  if ss -lnt 2>/dev/null | grep -q ":${PUERTO_DASHBOARD}[[:space:]]"; then
    ESCUCHA_8000="si"
  fi
elif command -v netstat >/dev/null 2>&1; then
  if netstat -lnt 2>/dev/null | grep -q ":${PUERTO_DASHBOARD}[[:space:]]"; then
    ESCUCHA_8000="si"
  fi
else
  aviso "Sin 'ss' ni 'netstat': no se pudo comprobar el puerto ${PUERTO_DASHBOARD}."
fi

if [ "$ESCUCHA_8000" = "si" ]; then
  ok "Puerto ${PUERTO_DASHBOARD} escuchando."
else
  error "El puerto ${PUERTO_DASHBOARD} no está escuchando."
fi

if command -v curl >/dev/null 2>&1 && [ "$ESCUCHA_8000" = "si" ]; then
  # /api/health es una ruta real de Coolify (routes/api.php: prefix 'api' + /health).
  if RESPUESTA="$(curl -fsS --max-time 10 "http://127.0.0.1:${PUERTO_DASHBOARD}/api/health" 2>/dev/null)"; then
    ok "El panel responde en /api/health: ${RESPUESTA}"
  else
    error "El panel no respondió en http://127.0.0.1:${PUERTO_DASHBOARD}/api/health"
    aviso "Puede que el contenedor siga arrancando, o que un firewall local bloquee la consulta."
  fi
fi

if [ -n "${1:-}" ]; then
  info ""
  info "Probando el panel desde fuera con la URL indicada: ${1}"
  if command -v curl >/dev/null 2>&1 && curl -fsS --max-time 10 "${1%/}/api/health" >/dev/null 2>&1; then
    ok "La URL externa responde."
  else
    aviso "La URL externa no respondió /api/health. Revisa puertos 80/443 y el dominio."
  fi
fi

info ""
info "  Puertos que upstream indica para el firewall:"
info "    ${PUERTO_DASHBOARD}/tcp  acceso directo al panel (http://<ip-del-servidor>:8000)"
info "    ${PUERTO_REALTIME}/tcp  actualizaciones en tiempo real del panel (acceso por IP)"
info "    ${PUERTO_TERMINAL}/tcp  terminal web del panel (acceso por IP)"
info "    22/tcp  SSH | 80/tcp y 443/tcp  tráfico y certificados vía el proxy"
info "  Tras configurar el dominio del panel, se pueden cerrar ${PUERTO_DASHBOARD}, ${PUERTO_REALTIME} y ${PUERTO_TERMINAL}."

# =============================================================================
# 5. Secretos de la instancia
# =============================================================================
titulo "Secretos de la instancia"

if [ -f "$ENV_FILE" ]; then
  ok "Existe ${ENV_FILE}"
  PERMISOS="$(stat -c '%a' "$ENV_FILE" 2>/dev/null || stat -f '%Lp' "$ENV_FILE" 2>/dev/null || echo '?')"
  if [ "$PERMISOS" = "700" ]; then
    ok "Permisos correctos (700)."
  else
    aviso "Permisos ${PERMISOS}; el instalador oficial deja este archivo en 700."
  fi

  DUENO="$(stat -c '%U:%G' "$ENV_FILE" 2>/dev/null || stat -f '%Su:%Sg' "$ENV_FILE" 2>/dev/null || echo '?')"
  info "  Propietario: ${DUENO} (el instalador oficial usa 9999:root en source/)"

  # Solo se confirma la presencia de la clave; NUNCA se imprime su valor.
  if grep -q '^APP_KEY=' "$ENV_FILE"; then
    ok "APP_KEY presente (valor no mostrado a propósito)."
  else
    error "No hay línea APP_KEY= en ${ENV_FILE}."
  fi
else
  error "No existe ${ENV_FILE}. Sin ese archivo la instancia no arranca bien y no se pueden descifrar las credenciales guardadas."
fi

if [ -d "${DATA_DIR}/ssh/keys" ]; then
  ok "Existe ${DATA_DIR}/ssh/keys (claves que usa Coolify para conectarse por SSH a los servidores)."
else
  aviso "No existe ${DATA_DIR}/ssh/keys."
fi

# =============================================================================
# 6. Resumen y recordatorio
# =============================================================================
titulo "Resumen"
info "  Problemas: ${PROBLEMAS} | Avisos: ${AVISOS}"

info ""
info "  PASOS SIGUIENTES"
info "    1. Abre http://<ip-del-servidor>:${PUERTO_DASHBOARD} y crea la primera cuenta."
info "    2. En Settings, fija el dominio del panel con https:// para sacarlo del puerto ${PUERTO_DASHBOARD}."
info "    3. CIERRA ${PUERTO_DASHBOARD}, ${PUERTO_REALTIME} y ${PUERTO_TERMINAL} al público una vez que el dominio funcione."
info "    4. RESPALDA ESTE ARCHIVO AHORA. El APP_KEY que contiene cifra las credenciales"
info "       guardadas en la base: sin él, un respaldo de la base no se puede recuperar."
info "         grep '^APP_KEY=' ${ENV_FILE}"
info "       y copia la línea completa a un gestor de contraseñas fuera de este servidor."
info "    5. Deja configurado el respaldo de Coolify:"
info "         Settings > Backup > Configure backup  (respaldos diarios + copia S3)"
info "       y además el respaldo de disco completo del kit:"
info "         ./scripts/backup-coolify.sh"
info ""
if [ "$PROBLEMAS" -gt 0 ]; then
  error "Hay ${PROBLEMAS} problema(s). La instalación no está lista para entregar al cliente."
  exit 1
fi
ok "Sin problemas bloqueantes. La instalación parece correcta."
exit 0
