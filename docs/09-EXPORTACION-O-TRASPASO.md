# 09 — Exportación o traspaso

Este documento responde dos preguntas distintas que se confunden:

1. ¿Cómo se sacan los datos **de la instancia Coolify**?
2. ¿Cómo se traspasa a otra plataforma (Odoo, otro panel, otro proveedor)?

Y deja clarísimo algo que se promete mal: **este kit no incluye ningún conector.**
Un archivo exportado es una foto, no una sincronización.

---

## 1. Qué es realmente exportable

### 1.1 De la instancia del panel

| Dato | Dónde está | Formato |
|---|---|---|
| Proyectos, recursos, ajustes, historial de despliegues | Base interna `coolify-db` | Volcado de PostgreSQL (`pg_dump`) |
| Secretos de instalación | `/data/coolify/source/.env` | Archivo de texto |
| Claves SSH de la instancia | `/data/coolify/ssh/keys/` | Archivos de clave |
| Configuración del proxy | `/data/coolify/proxy/` | Archivos |

El respaldo del kit (`scripts/backup-coolify.sh`) se lleva **todo eso**, que es
lo que hay que entregarle a un cliente que se va.

```bash
# Exportar la base en un archivo portable
sudo docker exec coolify-db pg_dump \
  --username=coolify --dbname=coolify --format=custom \
  > coolify-db.dmp
```

### 1.2 De las aplicaciones del cliente

Cada aplicación tiene sus propios datos. Coolify no los exporta por el cliente:

- **Volúmenes Docker** de las aplicaciones y bases de datos.
- Volúmenes de los recursos de tipo base de datos.

```bash
# Volcado de una base PostgreSQL genérica (el motor depende de cada app)
sudo docker exec <contenedor-postgres> pg_dump -U <usuario> <base> > app.sql

# Volcado de una base MySQL genérica
sudo docker exec <contenedor-mysql> mysqldump -u <usuario> -p <base> > app.sql

# Copia de un volumen Docker
sudo docker run --rm -v <volumen>:/datos -v "$PWD":/respaldo alpine \
  tar czf /respaldo/volumen.tar.gz -C /datos .
```

El motor concreto **depende de cada aplicación**; el kit no asume cuál usa.

---

## 2. Traspaso de servidor (el caso real más común)

El cliente se va a otro proveedor, pero sigue usando Coolify. El procedimiento
probado por la operación es:

1. **Respaldo completo** del kit en el servidor actual.
2. En el **servidor nuevo**: instalar Docker, luego el panel con el script
   oficial.
3. **Restaurar** con `scripts/restore-coolify.sh`:
   ```bash
   sudo ./scripts/restore-coolify.sh --respaldo /ruta/al/respaldo
   ```
4. Revisar con los servicios detenidos (el script los deja apagados a
   propósito) y, si corresponde, restaurar la base con `--ejecutar-base`.
5. `sudo ./scripts/post-instalacion.sh`
6. **Cambiar los DNS** de los dominios de las apps al nuevo servidor, uno por
   uno, comprobando cada cambio.
7. Verificar que Coolify sigue pudiendo conectarse por SSH a los servidores.

**El `APP_KEY` debe viajar con el respaldo.** Sin él, las credenciales guardadas
en el panel no se descifran y el traspaso "funciona a medias".

---

## 3. Coolify → Odoo u otra plataforma

### 3.1 La verdad primero

**Este kit no incluye ningún conector a Odoo ni a ninguna otra plataforma.**

Lo que sí existe es la **API de Coolify**, que permite automatizar sobre la
instancia:

- Prefijo `/api`, versiones bajo `/api/v1/...`.
- Autenticación: `Authorization: Bearer <id>|<secreto>`.
- Permisos: `read`, `write`, `read:sensitive`, `root` (documentados).
- Debe estar habilitada en la instancia.

Verificado en la documentación oficial y en el código del repositorio (rama
`v4.x`). Ver [`02-INSTALACION-COOLIFY.md`](02-INSTALACION-COOLIFY.md), sección 6.

### 3.2 Conector implementado vs. guía de integración

| | Estado | Qué significa |
|---|---|---|
| **Conector a Odoo** | **No existe en este kit** | No hay código que escriba en Odoo |
| **API de Coolify** | **Sí existe, documentada por upstream** | Es la puerta de entrada para construir un conector |
| **Guía de integración** | Sí, conceptual | Requiere desarrollo propio |

Un CSV exportado **no es una sincronización automática**. Si el cliente pide
"sincronizar con Odoo", eso es un proyecto de desarrollo con su cotización, no
una característica del producto.

### 3.3 Si hay que construir el conector

Decisiones que hay que tomar antes de escribir código:

1. **Qué se traspasa:** ¿solo datos? ¿También configuraciones? ¿Historial?
2. **Quién manda:** Odoo como maestro, o Coolify.
3. **Frecuencia:** por eventos (webhook), por cron o manual.
4. **Errores:** qué pasa si Odoo está caído a mitad de una sincronización.
5. **Secretos:** el token de la API es una credencial de pleno acceso. Va en un
   gestor de secretos, nunca en el código ni en un `.env` versionado.

El kit **no implementa** nada de esto. Si Hefesto lo toma, es trabajo nuevo y
tiene sus propias pruebas.

---

## 4. Lo que este documento NO verifica

- No se probó un traspaso de servidor real. Los pasos salen del procedimiento
  documentado por upstream y del diseño del kit, no de una ejecución.
- No se verificó qué endpoints de la API de Coolify sirven para leer recursos en
  detalle: hay que leer la referencia de la API de la versión instalada antes de
  construir cualquier cosa encima.
- No hay exportador a formatos de negocio (CSV, XLSX) incluido. Si se necesita,
  hay que desarrollarlo.
