# 06 — Actualizaciones y reversión

Actualizar Coolify cambia el plano de control. No actualiza las aplicaciones,
bases de datos ni servicios que administra. Eso es exactamente lo que dice
upstream:

> "Updating Coolify changes the self-hosted Coolify control plane. It does not
> update the applications, databases, services, or servers you manage with
> Coolify."

Fuente: <https://coolify.io/docs/core/instance-management/update>

---

## 1. La vía oficial de actualización

### 1.1 Desde el panel (la recomendada)

1. En la barra lateral, **Settings → Updates**.
2. Coolify consulta su archivo de versiones en el CDN y muestra cuál es la
   disponible.
3. Puedes configurar la **frecuencia de verificación** con una expresión cron.
   El valor por defecto documentado es `0 0 * * *` (todos los días a medianoche,
   en la zona horaria de la instancia).
4. Al instalar una actualización, **Coolify se reinicia**. El panel queda
   indisponible un momento, normalmente menos de un minuto.

**Importante:** si `AUTOUPDATE` está definido en
`/data/coolify/source/.env`, la opción de frecuencia de actualización **no
aparece** en el panel. Es un comportamiento documentado por upstream.

### 1.2 Desde el servidor (línea de comandos)

El script que instala Coolify también es el que actualiza. Está en
`/data/coolify/source/upgrade.sh` y su firma, verificada leyendo el archivo,
es:

```bash
bash /data/coolify/source/upgrade.sh [version] [helper-version] [registry] [skip-backup]
```

| Argumento | Qué es | Valor por defecto |
|---|---|---|
| `$1` | Versión de la imagen del panel | `latest` |
| `$2` | Versión del helper | `latest` |
| `$3` | Registro de imágenes | `REGISTRY_URL` del `.env`, o `docker.io` |
| `$4` | Saltar el respaldo previo | `false` |

Ejemplo con versión fija, que es lo que conviene en operación:

```bash
sudo bash /data/coolify/source/upgrade.sh v4.4.6 1.0.17 docker.io false
```

El script escribe un log con fecha en `/data/coolify/source/upgrade-<fecha>.log`
y un estado en `/data/coolify/source/.upgrade-status`.

> **No uses `--force` sobre `install.sh` para actualizar.** Ese script es de
> instalación limpia. Para actualizar, el script correcto es `upgrade.sh`, que ya
> está en el servidor.

### 1.3 Antes de actualizar, sí o sí

Upstream lo pide explícitamente, y tiene sentido:

1. **Crear un respaldo de la instancia** (`scripts/backup-coolify.sh`).
2. **Leer las notas de la versión** que vas a instalar.
3. **Revisar que no haya despliegues en curso**: pueden fallar durante el proceso.

Y añade uno que el kit refuerza:

4. **Anotar la versión actual** antes de tocar nada. Queda en `MANIFESTO.txt`
   de cada respaldo.

---

## 2. Versiones fijadas

El kit opera con la versión **v4.4.6** (verificada el 2026-10-16 en
`https://api.github.com/repos/coollabsio/coolify/releases/latest`, publicada el
2026-10-09, marcada como `prerelease: false`).

Detalle y fuentes en [`VERSION.md`](../VERSION.md).

Riesgo asumido: si el panel usa `:latest` (comportamiento por defecto del
compose oficial), una actualización automática puede cambiar de versión sin que
nadie lo decida. Para operación comercial conviene **fijar la versión**.

---

## 3. Cómo volver atrás

### 3.1 La advertencia principal

**Volver atrás no es una operación simétrica.** Coolify, al actualizarse, ejecuta
migraciones de base de datos (Laravel). Estas migraciones pueden:

- agregar columnas, tablas o índices (y por tanto no siempre se pueden deshacer);
- transformar datos de forma que la versión anterior no entienda;
- dejar la base en un estado que la versión anterior no sabe leer.

Por eso **restaurar la base de una versión nueva sobre una versión vieja puede
dejar el panel inutilizable.** Upstream no publica un procedimiento de reversión
de migraciones para el panel; el `upgrade-postgres.sh` que descarga el
instalador se ocupa de la base, no de deshacer cambios.

### 3.2 El camino seguro para volver atrás

Es una restauración, no un "downgrade":

1. Instalar la versión anterior (o la que se quiera) en un servidor limpio.
2. Restaurar el respaldo **de esa versión** (base de datos **y** `/data/coolify`).
3. Verificar que la versión del respaldo coincide con la del servidor.

```bash
# 1. Servidor limpio con la versión anterior instalada
# 2. Restaurar (sin --force si el destino está vacío)
sudo ./scripts/restore-coolify.sh --respaldo /data/backups/coolify/<marca-antigua>
# 3. Verificar antes de tocar la base
sudo docker inspect --format '{{.Config.Image}}' coolify
sudo grep '^APP_KEY=' /data/coolify/source/.env   # y comprobarlo, no imprimirlo
```

**Por eso el `MANIFESTO.txt` registra la imagen del panel.** Sin ese dato, no se
puede saber si un respaldo es compatible con el servidor donde se restaura.

### 3.3 Lo que sí se puede hacer sin riesgo

- **Reiniciar** el contenedor `coolify`: no cambia versión ni base.
- **Reconstruir** un contenedor de aplicación: no toca el panel.
- **Cambiar una variable del `.env`** que no sea `APP_KEY` ni una credencial, con
  el servicio detenido.

---

## 4. Política de actualización para Hefesto

Propuesta para el servicio VPS administrado:

| Situación | Política |
|---|---|
| Actualización de seguridad | Aplicar en ventana de mantenimiento, con respaldo previo verificado |
| Actualización menor | Aplicar, avisando al cliente con antelación |
| Actualización mayor | Anotar en bitácora, probar en un servidor paralelo antes |
| Automática sin supervisión | **No.** Si se deja `AUTOUPDATE`, que sea con respaldo diario comprobado |

**Regla operativa:** una actualización del panel **siempre** va precedida de un
respaldo verificado y seguida de una comprobación con
`post-instalacion.sh`. Si el panel no vuelve, se restaura: por eso existe el
respaldo.

---

## 5. Registro de versiones del cliente

Para cada cliente, conviene llevar una tabla así:

| Fecha | Versión anterior | Versión nueva | Respaldo previo | Resultado | Quién |
|---|---|---|---|---|---|
| | | | | | |

Es un control simple y es la diferencia entre "se actualizó" y "se puede
explicar qué pasó".

---

## 6. Pendiente de verificar

- No se ejecutó ninguna actualización real. No hay servidor en este entorno.
- No se probó el comportamiento exacto del panel cuando la actualización falla a
  mitad de camino (qué queda a medias y cómo se recupera).
- No se verificó si `upgrade.sh` admite volver a una versión anterior sin
  restaurar la base. **La documentación de upstream no publica un procedimiento
  de reversión**, así que el kit no afirma que exista.
