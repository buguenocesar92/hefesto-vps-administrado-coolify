#!/usr/bin/env bash
# =============================================================================
# backup-coolify.sh
# Hefesto Studio — Kit "VPS administrado Hefesto" (Coolify)
#
# QUE HACE
#   Genera un respaldo coherente de la instancia de Coolify:
#     1. Detiene los contenedores que ESCRIBEN estado (coolify, coolify-redis y
#        coolify-proxy si existen) para que el sistema de archivos no cambie
#        mientras se copia.
#     2. Vuelca la base de datos de Coolify con pg_dump desde el contenedor
#        coolify-db (volcado lógico y coherente, formato "custom").
#     3. Copia /data/coolify completo (incluye source/.env y ssh/keys).
#     4. Escribe un manifiesto y un archivo SHA256SUMS.
#     5. Verifica los SHA-256 y SOLO al terminar bien marca el respaldo como
#        completo. Nunca antes.
#     6. Vuelve a levantar los contenedores que estaban corriendo.
#
# QUE NO HACE
#   - No detiene coolify-db: se necesita vivo para el pg_dump.
#   - No toca ni modifica nada fuera de /data/coolify y del destino de respaldo.
#   - No imprime el valor de APP_KEY ni de ningún secreto.
#
# ESTADO DEL KIT
#   Este script NO se ha ejecutado en un servidor real. El kit se entrega en
#   estado "kit preparado". Ver docs/07-PRUEBAS-DE-ACEPTACION.md.
#
# FUENTES
#   - Los datos viven en /data/coolify y los secretos en
#     /data/coolify/source/.env:
#     https://coolify.io/docs/start-with-self-hosted
#   - Copia de la base con pg_dump / restauración oficial con pg_restore:
#     https://coolify.io/docs/core/backup-and-recovery/instance-restore
#   - APP_KEY cifra las credenciales guardadas y no va en el respaldo de la BD:
#     https://coolify.io/docs/core/backup-and-recovery/instance-backup
# =============================================================================

set -euo pipefail

# --- Configuración -----------------------------------------------------------
DATA_DIR="${COOLIFY_DATA_DIR:-/data/coolify}"
BACKUP_ROOT="${BACKUP_ROOT:-/data/backups/coolify}"

CONT_COOLIFY="coolify"
CONT_DB="coolify-db"
CONT_REDIS="coolify-redis"
CONT_PROXY="coolify-proxy"

MARCA_TIEMPO="$(date -u +%Y%m%dT%H%M%SZ)"
DIR_FINAL="${BACKUP_ROOT}/${MARCA_TIEMPO}"
DIR_STAGING="${BACKUP_ROOT}/.incompleto-${MARCA_TIEMPO}"
ARCHIVO_DB="coolify-db.dmp"

# Contenedores que este script detuvo, para restaurarlos al final.
CONTENEDORES_DETENIDOS=()

# --- Presentación ------------------------------------------------------------
if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ] && [ -z "${NO_COLOR:-}" ]; then
  C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_BOLD=$'\033[1m'; C_OFF=$'\033[0m'
else
  C_OK=""; C_WARN=""; C_ERR=""; C_BOLD=""; C_OFF=""
fi

info()   { printf '%s\n' "$*"; }
titulo() { printf '\n%s== %s ==%s\n' "$C_BOLD" "$*" "$C_OFF"; }
ok()     { printf '  %s[OK]%s %s\n' "$C_OK" "$C_OFF" "$*"; }
aviso()  { printf '  %s[AVISO]%s %s\n' "$C_WARN" "$C_OFF" "$*"; }
error()  { printf '  %s[ERROR]%s %s\n' "$C_ERR" "$C_OFF" "$*"; }

fatal()  { error "$*"; exit 1; }

uso() {
  cat <<'EOF'
Uso: backup-coolify.sh [--destino RUTA]

  --destino RUTA  Carpeta donde se dejan los respaldos.
                   Por defecto: /data/backups/coolify
                   Puede fijarse también con la variable de entorno BACKUP_ROOT.
  --origen RUTA   Carpeta de datos de Coolify (solo para pruebas).
                   Por defecto: /data/coolify
  -h, --help      Muestra esta ayuda.

Notas
  - Requiere root y acceso al socket de Docker.
  - Durante la copia el panel queda unos segundos sin responder: es
    intencional, para no respaldar archivos a medio escribir.
  - El respaldo queda en "<destino>/<marca-de-tiempo>/" y solo se considera
    bueno cuando existe el archivo COMPLETO dentro de esa carpeta.

Códigos de salida
  0  respaldo completo y verificado
  1  fallo: no se creó ningún respaldo completo (se limpia el staging)
EOF
}

# --- Parseo de argumentos ----------------------------------------------------
while [ "$#" -gt 0 ]; do
  case "$1" in
    --destino) BACKUP_ROOT="${2:?--destino requiere una ruta}"; shift ;;
    --origen)  DATA_DIR="${2:?--origen requiere una ruta}"; shift ;;
    -h|--help) uso; exit 0 ;;
    *) printf 'Opción desconocida: %s\n\n' "$1" >&2; uso >&2; exit 1 ;;
  esac
  shift
done

# =============================================================================
# Utilidades
# =============================================================================

# Devuelve 0 si el contenedor indicado existe.
contenedor_existe() {
  docker inspect "$1" >/dev/null 2>&1
}

# Devuelve 0 si el contenedor indicado está corriendo.
contenedor_corriendo() {
  [ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null || echo false)" = "true" ]
}

# Limpieza: reinicia lo que se detuvo y borra el staging incompleto.
limpiar() {
  local codigo=$?

  # Devuelve los contenedores que este script detuvo, en orden inverso.
  local indice
  for (( indice=${#CONTENEDORES_DETENIDOS[@]}-1; indice>=0; indice-- )); do
    local cont="${CONTENEDORES_DETENIDOS[$indice]}"
    if contenedor_existe "$cont"; then
      if docker start "$cont" >/dev/null 2>&1; then
        ok "Contenedor ${cont} vuelto a levantar."
      else
        error "No se pudo volver a levantar ${cont}. Revísalo a mano."
      fi
    fi
  done

  if [ "$codigo" -ne 0 ] && [ -d "$DIR_STAGING" ]; then
    rm -rf "$DIR_STAGING"
    aviso "Se eliminó el respaldo incompleto: ${DIR_STAGING}"
  fi
  return $codigo
}
trap limpiar EXIT

# =============================================================================
# 1. Validaciones previas
# =============================================================================
titulo "Validaciones previas"

[ "$(id -u)" -eq 0 ] || fatal "Se requiere root para leer /data/coolify y usar Docker."

command -v docker >/dev/null 2>&1 || fatal "Docker no está instalado o no está en el PATH."
docker info >/dev/null 2>&1    || fatal "No se pudo contactar con el demonio Docker."

command -v sha256sum >/dev/null 2>&1 || fatal "Falta 'sha256sum' (paquete coreutils)."

# Origen: debe existir, ser directorio y no ser una ruta peligrosa.
[ -d "$DATA_DIR" ] || fatal "No existe el directorio de datos de Coolify: ${DATA_DIR}"
ORIGEN_REAL="$(realpath "$DATA_DIR")"
case "$ORIGEN_REAL" in
  "/" ) fatal "El origen resuelto es '/'. Aborto por seguridad." ;;
  "/data") fatal "El origen resuelto es '/data'. Aborta por seguridad." ;;
esac
[ -n "$ORIGEN_REAL" ] || fatal "No se pudo resolver la ruta real del origen."
ok "Origen de datos: ${ORIGEN_REAL}"

[ -f "${ORIGEN_REAL}/source/.env" ] || \
  aviso "No se encuentra ${ORIGEN_REAL}/source/.env. Si Coolify está mal instalado, repórtalo antes de seguir."
contenedor_existe "$CONT_DB" || fatal "No existe el contenedor ${CONT_DB}. ¿Está Coolify instalado en este servidor?"
contenedor_corriendo "$CONT_DB" || fatal "El contenedor ${CONT_DB} no está corriendo: no se puede volcar la base de datos."

# Destino: se resuelve aunque no exista todavía.
DESTINO_REAL="$(realpath -m "$BACKUP_ROOT")"
[ -n "$DESTINO_REAL" ] || fatal "No se pudo resolver la ruta real del destino."
case "$DESTINO_REAL" in
  "/") fatal "El destino resuelto es '/'. Aborto por seguridad." ;;
  /*) ;;
  *) fatal "El destino debe ser una ruta absoluta: ${DESTINO_REAL}" ;;
esac

# El destino nunca puede vivir dentro del origen (se copiaría a sí mismo).
case "$DESTINO_REAL/" in
  "${ORIGEN_REAL}"/*) fatal "El destino (${DESTINO_REAL}) está dentro del origen (${ORIGEN_REAL}). Aborto." ;;
esac
case "$ORIGEN_REAL/" in
  "${DESTINO_REAL}"/*) aviso "El origen está dentro del destino: revisa el tamaño del respaldo." ;;
esac
ok "Destino de respaldos: ${DESTINO_REAL}"

mkdir -p "$DESTINO_REAL"
chmod 700 "$DESTINO_REAL"
mkdir -p "$DIR_STAGING"
chmod 700 "$DIR_STAGING"

# =============================================================================
# 2. Metadatos de la instancia
# =============================================================================
titulo "Metadatos"

IMAGEN_PANEL="desconocida"
if contenedor_existe "$CONT_COOLIFY"; then
  IMAGEN_PANEL="$(docker inspect -f '{{.Config.Image}}' "$CONT_COOLIFY" 2>/dev/null || echo desconocido)"
fi
HOSTNAME_SERVIDOR="$(hostname 2>/dev/null || echo desconocido)"
ok "Imagen del panel: ${IMAGEN_PANEL}"
ok "Servidor: ${HOSTNAME_SERVIDOR}"

# =============================================================================
# 3. Detener a los escritores
# =============================================================================
titulo "Coordinando escritores"

# No se detiene coolify-db: es quien produce el pg_dump.
for CONT in "$CONT_COOLIFY" "$CONT_REDIS" "$CONT_PROXY"; do
  if contenedor_existe "$CONT"; then
    if contenedor_corriendo "$CONT"; then
      info "  Deteniendo ${CONT}..."
      docker stop --time 30 "$CONT" >/dev/null 2>&1 || fatal "No se pudo detener ${CONT}."
      CONTENEDORES_DETENIDOS+=("$CONT")
    else
      info "  ${CONT} ya estaba detenido."
    fi
  else
    info "  ${CONT} no existe en este servidor: se omite."
  fi
done
ok "Escritores detenidos. El panel queda unos segundos sin responder."

# =============================================================================
# 4. Volcado lógico de la base de datos
# =============================================================================
titulo "Volcado de la base de datos (${ARCHIVO_DB})"

info "  pg_dump desde ${CONT_DB} (formato custom, con --clean --if-exists)."
# El formato custom es el que espera el pg_restore oficial documentado.
if ! docker exec "$CONT_DB" pg_dump \
      --username=coolify \
      --dbname=coolify \
      --format=custom \
      --clean \
      --if-exists \
      --no-owner \
      --no-acl \
      > "${DIR_STAGING}/${ARCHIVO_DB}"; then
  fatal "pg_dump falló. No se creó ningún respaldo completo."
fi

[ -s "${DIR_STAGING}/${ARCHIVO_DB}" ] || fatal "El volcado quedó vacío: no se creó ningún respaldo completo."

# Verificación real: el archivo debe ser legible como archivo de pg_restore.
TOTAL_OBJETOS="$(docker exec -i "$CONT_DB" pg_restore --list < "${DIR_STAGING}/${ARCHIVO_DB}" 2>/dev/null | grep -c '^[0-9]' || true)"
if [ "${TOTAL_OBJETOS:-0}" -lt 1 ]; then
  fatal "El volcado no es legible con 'pg_restore --list'. No se creó ningún respaldo completo."
fi
ok "Volcado legibles: ${TOTAL_OBJETOS} objetos listados."

# =============================================================================
# 5. Copia de archivos
# =============================================================================
titulo "Copia de ${ORIGEN_REAL}"

mkdir -p "${DIR_STAGING}/data"
info "  Copiando (incluye source/.env y ssh/keys)..."
cp -a "${ORIGEN_REAL}/." "${DIR_STAGING}/data/"
ok "Copia terminada."

# =============================================================================
# 6. Manifiesto
# =============================================================================
titulo "Manifiesto"

TAMANO_TOTAL="$(du -sh "$DIR_STAGING" 2>/dev/null | cut -f1)"
cat > "${DIR_STAGING}/MANIFESTO.txt" <<EOF
# Manifiesto de respaldo de Coolify
# Generado por el kit Hefesto (scripts/backup-coolify.sh)
# No contiene APP_KEY ni contraseñas en texto: esos viven en data/source/.env

marca_de_tiempo_utc   : ${MARCA_TIEMPO}
fecha_utc              : $(date -u +"%Y-%m-%d %H:%M:%S UTC")
servidor               : ${HOSTNAME_SERVIDOR}
imagen_del_panel       : ${IMAGEN_PANEL}
origen                 : ${ORIGEN_REAL}
destino                : ${DIR_FINAL}
tamano_total           : ${TAMANO_TOTAL}
volcado_base_de_datos  : ${ARCHIVO_DB} (pg_dump formato custom, ${TOTAL_OBJETOS} objetos)
carpetas_copiadas      : data/ (copia integra de ${ORIGEN_REAL})
version_del_kit        : Hefesto coolify-vps-gestionado 1.0.0

# Verifica la integridad con:
#   cd <esta-carpeta> && sha256sum -c SHA256SUMS
#
# Contiene datos sensibles (source/.env con APP_KEY y claves de la instancia).
# Trátalo como un secreto: no lo subas a un repositorio ni a un bucket público.
EOF
ok "MANIFESTO.txt escrito."

# =============================================================================
# 7. Checksums
# =============================================================================
titulo "SHA-256"

# SHA256SUMS cubre todos los archivos salvo los marcadores de estado.
( cd "$DIR_STAGING" \
  && find . -type f ! -name 'SHA256SUMS' ! -name 'COMPLETO' -print0 \
   | sort -z \
   | xargs -0 --no-run-if-empty sha256sum > SHA256SUMS )
TOTAL_ARCHIVOS="$(wc -l < "${DIR_STAGING}/SHA256SUMS" | tr -d ' ')"
ok "SHA256SUMS generado para ${TOTAL_ARCHIVOS} archivos."

# Verificación real antes de declarar el respaldo bueno.
if ! ( cd "$DIR_STAGING" && sha256sum -c --quiet SHA256SUMS ); then
  fatal "Falló la verificación de SHA-256. No se creó ningún respaldo completo."
fi
ok "Verificación SHA-256 correcta."

# =============================================================================
# 8. Marca de completo y publicación atómica
# =============================================================================
titulo "Publicación"

# COMPLETO se escribe SOLO ahora, después de verificar todo.
cat > "${DIR_STAGING}/COMPLETO" <<EOF
completo=true
marca_de_tiempo_utc=${MARCA_TIEMPO}
archivos_verificados=${TOTAL_ARCHIVOS}
sha256_de_SHA256SUMS=$(sha256sum "${DIR_STAGING}/SHA256SUMS" | cut -d' ' -f1)
EOF

# El respaldo pasa a su nombre final de una sola vez: o aparece completo o no existe.
mv "$DIR_STAGING" "$DIR_FINAL"
chmod -R go-rwx "$DIR_FINAL"

info ""
ok "Respaldo completo: ${DIR_FINAL}"
info ""
info "Verifícalo cuando quieras con:"
info "    cd '${DIR_FINAL}' && sha256sum -c SHA256SUMS"
info ""
info "Recuerda: el respaldo de la base NO incluye el APP_KEY por sí solo."
info "Copia 'data/source/.env' a un lugar seguro fuera de este servidor."
