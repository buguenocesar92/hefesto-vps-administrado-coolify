#!/usr/bin/env bash
# =============================================================================
# restore-coolify.sh
# Hefesto Studio — Kit "VPS administrado Hefesto" (Coolify)
#
# QUE HACE
#   Restaura una instancia de Coolify desde un respaldo hecho con
#   backup-coolify.sh (o desde un .tar.gz de ese respaldo).
#
# REGLAS DE SEGURIDAD QUE IMPONE ESTE SCRIPT
#   - Rechaza destinos ocupados salvo que se pase --force de forma explícita.
#   - Verifica COMPLETO y todos los SHA-256 antes de tocar nada.
#   - Valida rutas antes de copiar o extraer: rechaza rutas absolutas,
#     "..", y cualquier cosa que se escape del destino (path traversal).
#   - NO ejecuta DROP ni pg_restore por su cuenta. Hay que pedirlo con
#     --ejecutar-base, y además confirmar escribiendo RESTAURAR.
#   - Al terminar deja los servicios DETENIDOS para que alguien revise.
#
# ESTADO DEL KIT
#   Este script NO se ha ejecutado en un servidor real. El kit se entrega en
#   estado "kit preparado". Ver docs/07-PRUEBAS-DE-ACEPTACION.md.
#
# FUENTES
#   - Procedimiento oficial de restauración (pg_restore y requisitos):
#     https://coolify.io/docs/core/backup-and-recovery/instance-restore
#   - APP_KEY y claves SSH que hay que conservar aparte:
#     https://coolify.io/docs/core/backup-and-recovery/instance-backup
# =============================================================================

set -euo pipefail

# --- Configuración -----------------------------------------------------------
DATA_DIR="${COOLIFY_DATA_DIR:-/data/coolify}"
CONT_COOLIFY="coolify"
CONT_DB="coolify-db"
CONT_REDIS="coolify-redis"
CONT_PROXY="coolify-proxy"

RESPALDO=""
ARCHIVO_DB="coolify-db.dmp"
USAR_FORCE="no"
EJECUTAR_BASE="no"
ASUME_SI="no"

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
Uso: restore-coolify.sh --respaldo RUTA [opciones]

  --respaldo RUTA   Carpeta de respaldo (con MANIFESTO.txt, SHA256SUMS y
                    COMPLETO) o archivo .tar.gz / .tar de esa carpeta.
                    Obligatorio.
  --destino RUTA    Carpeta donde se restaura. Por defecto: /data/coolify
  --force           Permite restaurar sobre un destino ya ocupado.
  --ejecutar-base   Ejecuta además el pg_restore documentado por upstream.
                    Sin esta opción el script deja la base de datos intacta.
  --si              No pide confirmación interactiva.
  -h, --help        Muestra esta ayuda.

Qué hace y qué no hace
  - Verifica los SHA-256 antes de escribir nada.
  - No borra ni sobrescribe nada sin --force.
  - Nunca hace DROP por su cuenta: la base de datos solo se toca con
    --ejecutar-base y escribiendo RESTAURAR.
  - Al terminar deja coolify, coolify-redis y coolify-proxy DETENIDOS.

Códigos de salida
  0  restauración de archivos terminada (servicios detenidos)
  1  aborted por validación o fallo: no se sobrescribió nada
  2  el operador canceló
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --respaldo)      RESPALDO="${2:?--respaldo requiere una ruta}"; shift ;;
    --destino)       DATA_DIR="${2:?--destino requiere una ruta}"; shift ;;
    --force)         USAR_FORCE="si" ;;
    --ejecutar-base) EJECUTAR_BASE="si" ;;
    --si)            ASUME_SI="si" ;;
    -h|--help)       uso; exit 0 ;;
    *) printf 'Opción desconocida: %s\n\n' "$1" >&2; uso >&2; exit 1 ;;
  esac
  shift
done

[ -n "$RESPALDO" ] || { uso >&2; fatal "Falta --respaldo."; }

# =============================================================================
# Utilidades
# =============================================================================
contenedor_existe()   { docker inspect "$1" >/dev/null 2>&1; }
contenedor_corriendo(){ [ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null || echo false)" = "true" ]; }

# Huella de una línea del .env (nunca imprime el valor).
hash_de_linea_env() {
  local archivo="$1" clave="$2"
  [ -f "$archivo" ] || { echo "sin-archivo"; return; }
  local valor
  valor="$(grep "^${clave}=" "$archivo" 2>/dev/null | head -n1 | cut -d'=' -f2- || true)"
  if [ -z "$valor" ]; then echo "sin-clave"; return; fi
  printf '%s' "$valor" | sha256sum | cut -c1-16
}

# =============================================================================
# 1. Validar el respaldo
# =============================================================================
titulo "Validando el respaldo"

[ -e "$RESPALDO" ] || fatal "No existe la ruta de respaldo: ${RESPALDO}"

# Si viene un .tar.gz, se valida la lista de miembros antes de extraer nada.
ORIGEN_DATOS=""
RUTA_TAR=""
case "$RESPALDO" in
  *.tar.gz|*.tgz|*.tar)
    RUTA_TAR="$RESPALDO"
    TAR_VERIFICADO="$RESPALDO"
    ;;
  *)
    [ -d "$RESPALDO" ] || fatal "El respaldo debe ser una carpeta o un archivo .tar.gz/.tar."
    ;;
esac

# members_ok verifica que ningún miembro del tar sea una ruta absoluta,
# contenga ".." o apunte fuera del directorio de extracción.
members_ok() {
  local archivo="$1"
  local miembro
  while IFS= read -r miembro; do
    case "$miembro" in
      /*)      echo "    ruta absoluta: ${miembro}"; return 1 ;;
      ../*|*/../*|*/..) echo "    componente '..': ${miembro}"; return 1 ;;
    esac
  done < <(tar -tzf "$archivo" 2>/dev/null || tar -tf "$archivo")
  return 0
}

if [ -n "$RUTA_TAR" ]; then
  ok "Respaldo comprimido: ${RUTA_TAR}"
  if members_ok "$RUTA_TAR"; then
    ok "La lista de miembros del tar es segura (sin rutas absolutas ni '..')."
  else
    fatal "El tar contiene rutas peligrosas. No se extrae nada."
  fi
  # Se extrae primero a un directorio aislado para poder verificarlo.
  DIR_AISLADO="$(mktemp -d /tmp/coolify-restore-XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$DIR_AISLADO'" EXIT
  info "  Extrayendo a un directorio aislado para verificar..."
  tar -xzf "$RUTA_TAR" -C "$DIR_AISLADO" 2>/dev/null || tar -xf "$RUTA_TAR" -C "$DIR_AISLADO"
  # Si el tar tiene un nivel superior (carpeta/...), se entra a él.
  CANDIDATO="$(find "$DIR_AISLADO" -maxdepth 2 -name 'MANIFESTO.txt' -printf '%h\n' 2>/dev/null | head -n1 || true)"
  if [ -z "$CANDIDATO" ]; then
    fatal "El tar no contiene un MANIFESTO.txt reconocible."
  fi
  RESPALDO="$CANDIDATO"
  ok "Contenido del tar ubicado en: ${RESPALDO}"
fi

RESPALDO_REAL="$(realpath "$RESPALDO")"
[ -d "$RESPALDO_REAL" ] || fatal "El respaldo no es un directorio: ${RESPALDO_REAL}"

[ -f "${RESPALDO_REAL}/COMPLETO" ] || \
  fatal "No existe COMPLETO en ${RESPALDO_REAL}: ese respaldo nunca terminó bien. No se restaura nada."
ok "Respaldo marcado como completo."

[ -f "${RESPALDO_REAL}/SHA256SUMS" ] || fatal "Falta SHA256SUMS en el respaldo."
info "  Verificando SHA-256..."
if ! ( cd "$RESPALDO_REAL" && sha256sum -c --quiet SHA256SUMS ); then
  fatal "Falló la verificación de SHA-256. No se escribe nada."
fi
ok "SHA-256 correctos."

[ -d "${RESPALDO_REAL}/data" ] || fatal "El respaldo no contiene la carpeta 'data/'."
ORIGEN_DATOS="${RESPALDO_REAL}/data"
ok "Datos del respaldo: ${ORIGEN_DATOS}"

[ -f "${RESPALDO_REAL}/${ARCHIVO_DB}" ] || aviso "No está el volcado ${ARCHIVO_DB} en este respaldo."

# Ningún enlace simbólico del respaldo debe apuntar fuera del destino.
ENLACE_MALO="$(find "$ORIGEN_DATOS" -type l 2>/dev/null | head -n1 || true)"
if [ -n "$ENLACE_MALO" ]; then
  aviso "El respaldo contiene enlaces simbólicos (por ejemplo ${ENLACE_MALO}). Se copian como enlaces, sin seguirlos."
fi

# =============================================================================
# 2. Validar el destino
# =============================================================================
titulo "Validando el destino"

DESTINO_REAL="$(realpath -m "$DATA_DIR")"
case "$DESTINO_REAL" in
  "/" ) fatal "El destino resuelto es '/'. Aborto por seguridad." ;;
  /*) ;;
  *) fatal "El destino debe ser una ruta absoluta: ${DESTINO_REAL}" ;;
esac

# El destino no puede estar dentro del propio respaldo (se copiaría a sí mismo).
case "$ORIGEN_DATOS/" in
  "${DESTINO_REAL}/"*) fatal "El destino está dentro del respaldo. Aborto." ;;
esac
ok "Destino: ${DESTINO_REAL}"

# Destino ocupado: aquí se exige --force.
if [ -d "$DESTINO_REAL" ] && [ -n "$(ls -A "$DESTINO_REAL" 2>/dev/null)" ]; then
  if [ "$USAR_FORCE" != "si" ]; then
    error "El destino ya tiene datos: ${DESTINO_REAL}"
    error "Para restaurar encima de todos modos, repite con --force."
    error "Si no estás seguro, no lo hagas: esto puede dejar la instancia inutilizable."
    exit 1
  fi
  aviso "El destino está ocupado y se continúa porque diste --force."
  aviso "Lo que ya existía y no viene en el respaldo NO se va a borrar."
else
  ok "El destino está vacío."
fi

# APP_KEY: si ya hay un .env con otra clave, las credenciales cifradas de la
# base restaurada no van a poder descifrarse. Se compara sin mostrar valores.
if [ -f "${DESTINO_REAL}/source/.env" ]; then
  HASH_DESTINO="$(hash_de_linea_env "${DESTINO_REAL}/source/.env" APP_KEY)"
  HASH_RESPALDO="$(hash_de_linea_env "${ORIGEN_DATOS}/source/.env" APP_KEY)"
  if [ "$HASH_DESTINO" != "$HASH_RESPALDO" ]; then
    error "El APP_KEY del destino no coincide con el del respaldo."
    error "  destino  (huella): ${HASH_DESTINO}"
    error "  respaldo (huella): ${HASH_RESPALDO}"
    error "Upstream advierte: no sigas salvo que la APP_KEY guardada sea la de esta instancia."
    [ "$USAR_FORCE" = "si" ] || exit 1
    aviso "Se continúa porque diste --force. Es probable que las credenciales guardadas no se puedan descifrar."
  else
    ok "El APP_KEY del destino coincide con el del respaldo."
  fi
fi

# =============================================================================
# 3. Confirmación
# =============================================================================
titulo "Resumen de la restauración"
info "  Respaldo : ${RESPALDO_REAL}"
info "  Destino  : ${DESTINO_REAL}"
info "  Base de datos: ${EJECUTAR_BASE}"

if [ "$ASUME_SI" != "si" ]; then
  if [ ! -t 0 ]; then
    fatal "Sin terminal no se puede confirmar. Revisa el resumen y usa --si solo si aceptas el riesgo."
  fi
  info ""
  printf '  Escribe exactamente RESTAURAR para continuar: '
  RESPUESTA=""
  read -r RESPUESTA || true
  if [ "$RESPUESTA" != "RESTAURAR" ]; then
    info "Cancelado. No se restauró nada."
    exit 2
  fi
fi

# =============================================================================
# 4. Detener servicios (y dejarlos detenidos)
# =============================================================================
titulo "Deteniendo servicios"

command -v docker >/dev/null 2>&1 || aviso "Docker no está disponible: solo se restaurarán archivos."

for CONT in "$CONT_COOLIFY" "$CONT_REDIS" "$CONT_PROXY"; do
  if contenedor_existe "$CONT"; then
    if contenedor_corriendo "$CONT"; then
      info "  Deteniendo ${CONT}..."
      docker stop --time 30 "$CONT" >/dev/null 2>&1 || aviso "No se pudo detener ${CONT}."
    fi
  fi
done
ok "Servicios detenidos. NO se volverán a levantar al final: revisa antes de arrancar."

# =============================================================================
# 5. Restaurar archivos
# =============================================================================
titulo "Restaurando archivos"

mkdir -p "$DESTINO_REAL"
cp -a "${ORIGEN_DATOS}/." "${DESTINO_REAL}/"
ok "Archivos copiados a ${DESTINO_REAL}"

# Permisos que espera el instalador oficial:
#   chown -R 9999:root /data/coolify/{source,ssh,images}
#   chmod -R 700        /data/coolify/{source,ssh,images}
chown -R 9999:root "${DESTINO_REAL}/source" "${DESTINO_REAL}/ssh" "${DESTINO_REAL}/images" 2>/dev/null || \
  aviso "No se pudo ajustar el propietario (9999:root) de source/ssh/images."
chmod -R 700 "${DESTINO_REAL}/source" "${DESTINO_REAL}/ssh" "${DESTINO_REAL}/images" 2>/dev/null || \
  aviso "No se pudieron ajustar los permisos (700) de source/ssh/images."
ok "Propietario y permisos ajustados como en el instalador oficial."

# =============================================================================
# 6. Base de datos: solo si se pidió explícitamente
# =============================================================================
titulo "Base de datos"

COMANDO_PG_RESTORE="docker exec -i ${CONT_DB} pg_restore --clean --if-exists --exit-on-error --no-acl --no-owner --username=coolify --dbname=coolify < <ruta>/${ARCHIVO_DB}"

if [ "$EJECUTAR_BASE" != "si" ]; then
  aviso "No se tocó la base de datos (falta --ejecutar-base)."
  info ""
  info "Cuando revises el estado del servidor y decidas continuar, ejecuta el"
  info "comando oficial de upstream (documentado en la página de restauración):"
  info ""
  info "    ${COMANDO_PG_RESTORE}"
  info ""
  info "Ese comando limpia los objetos actuales de la base antes de cargar el"
  info "respaldo (--clean --if-exists): es equivalente a un DROP selectivo. Por"
  info "eso este script no lo ejecuta solo."
else
  [ -f "${RESPALDO_REAL}/${ARCHIVO_DB}" ] || fatal "No existe ${ARCHIVO_DB} en el respaldo."
  contenedor_existe "$CONT_DB" || fatal "No existe el contenedor ${CONT_DB}."
  contenedor_corriendo "$CONT_DB" || fatal "El contenedor ${CONT_DB} no está corriendo: levántalo a mano y repite."
  if [ "$ASUME_SI" != "si" ]; then
    if [ ! -t 0 ]; then fatal "Sin terminal no se puede confirmar el pg_restore."; fi
    printf '  Esto limpia los objetos actuales de la base. Escribe RESTAURAR: '
    RESPUESTA=""
    read -r RESPUESTA || true
    [ "$RESPUESTA" = "RESTAURAR" ] || { info "Cancelado."; exit 2; }
  fi
  info "  Ejecutando pg_restore oficial..."
  if ! docker exec -i "$CONT_DB" pg_restore \
        --clean \
        --if-exists \
        --exit-on-error \
        --no-acl \
        --no-owner \
        --username=coolify \
        --dbname=coolify \
        < "${RESPALDO_REAL}/${ARCHIVO_DB}"; then
    fatal "pg_restore falló. La base quedó en un estado parcial: revisa antes de seguir."
  fi
  ok "pg_restore terminado."
fi

# =============================================================================
# 7. Cierre: servicios detenidos a propósito
# =============================================================================
titulo "Listo: servicios detenidos"
info ""
info "  Coolify quedó con los archivos restaurados y los servicios apagados."
info ""
info "  Antes de arrancarlo, revisa:"
info "    - que /data/coolify/source/.env exista y tenga permisos 700"
info "    - que el APP_KEY sea el de esta instancia (afecta las credenciales guardadas)"
info "    - que /data/coolify/ssh/keys/ tenga las claves de la instancia original"
info "    - el estado de la base de datos, si restauraste con --ejecutar-base"
info ""
info "  Para arrancar y revisar:"
info "    docker start coolify && docker start coolify-redis"
info "    ./scripts/post-instalacion.sh"
info ""
info "  Este script NO inicia nada al final, a propósito: la revisión es humana."
