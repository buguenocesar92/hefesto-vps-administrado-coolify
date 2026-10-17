# 08 — Servicios comerciales

Este documento define qué se vende, qué no, y dónde termina la responsabilidad
de Hefesto. Está pensado para que la persona que cotiza no prometa lo que la
plataforma no garantiza.

---

## 1. El producto

**VPS administrado Hefesto**: un servidor con panel Coolify instalado y
configurado por Hefesto, con proxy HTTPS, respaldos y operación a cargo del
estudio.

Coolify es la herramienta; Hefesto es quien responde por el servicio.

---

## 2. El límite de responsabilidad: Coolify no es hosting

Esto hay que decirlo claro al cliente, por escrito, antes de cobrar.

> **Coolify no es un proveedor de hosting.** El software es un panel que
> administra servidores que tú aportas y tú pagas.

Lo que significa en concreto:

| | Cliente | Hefesto |
|---|---|---|
| Aporta y paga el servidor | **Sí** | No |
| Paga el nombre de dominio | **Sí** | No |
| Pide la licencia de Coolify | **No** | — |
| Opera el panel y los despliegues | — | **Sí** |
| Da soporte ante incidentes | — | **Sí** (dentro del alcance contratado) |

**Lo que Hefesto NO hace:** prestar servidores, revender capacidad de cómputo, ni
alojar aplicaciones de terceros en nombre del cliente.

Si el cliente quiere un hosting con todo incluido (que Hefesto aporte el
servidor), eso es **otro producto** y hay que cotizarlo aparte. Este kit no lo
cubre.

---

## 3. Qué incluye el servicio

### 3.1 Instalación inicial

- Preparación del servidor (Docker 24+, puertos, zona horaria).
- Instalación del panel con el script oficial.
- Verificación con `post-instalacion.sh`.
- **Extracción y entrega segura del `APP_KEY`** al cliente, o resguardo en el
  gestor de la operación si el cliente lo prefiere.
- Configuración del dominio del panel con HTTPS.
- Cierre de `8000`, `6001` y `6002` al público una vez funcionando por 443.
- Alta de la primera cuenta y entrega de las credenciales por un canal seguro.

### 3.2 Operación

- Monitoreo de disponibilidad del panel.
- Respaldo diario del panel (nativo de Coolify) y del kit
  (`backup-coolify.sh`), con copia fuera del servidor.
- **Restauración probada periódicamente**, no solo configurada.
- Actualizaciones del panel en ventana acordada, con respaldo previo verificado.
- Gestión de los despliegues que el cliente solicite.

### 3.3 Soporte

- Respuesta ante incidentes dentro de la ventana contratada.
- Bitácora de cambios: qué se hizo, cuándo y por qué.

---

## 4. La edición libre: qué hay detrás y qué no hay

Verificado:

- **Coolify es Apache-2.0**, y su licencia no impone límites de servidores,
  proyectos o sitios en la versión self-hosted.
- La documentación de upstream describe la opción self-hosted como **gratuita,
  salvo los costos del servidor**.

Fuente: <https://coolify.io/docs/usage> y la API de licencia del repositorio.

**Lo que esto significa comercialmente:** no existe una "edición comunitaria
recortada" a la que haya que pagar por lifted. El panel es el mismo, con todas
sus funciones. Lo que se cobra es **la operación**, que es justamente el trabajo
que el cliente no quiere hacer.

**Lo que no se puede prometer:**

- **No hay SLA de upstream.** Coolify no garantiza tiempos de respuesta por usar
  su software en tu servidor.
- **No hay soporte de upstream en la versión self-hosted.** Coolify Cloud es un
  producto distinto y pago. Si el cliente quiere ese respaldo, se cotiza como
  algo aparte.
- **No se puede prometer una versión futura.** Hoy v4.4.6; mañana puede cambiar.

---

## 5. El límite que más cuesta: no es multi-tenant

**Debe quedar por escrito en el contrato.**

Una instancia de Coolify administra los servidores de un cliente. Si Hefesto
opera varios clientes **en una misma instancia compartida**:

- No hay aislamiento entre ellos.
- Cualquiera con acceso administrativo al panel ve **todos** los servidores de
  **todos** los clientes.
- Una compromiso de esa instancia afecta a todos los clientes a la vez.

Detalle en [`04-PRIMERA-CUENTA-Y-USUARIOS.md`](04-PRIMERA-CUENTA-Y-USUARIOS.md),
sección 4.

**Dos modelos defendibles:**

| Modelo | Cuándo | Riesgo |
|---|---|---|
| **Instancia dedicada por cliente** | Clientes que requieren aislamiento, o con datos sensibles | Más servidores (costo) |
| **Instancia compartida administrada solo por Hefesto** | Clientes que no acceden al panel y aceptan operación opaca | Riesgo compartido concentrado |

**Lo que no es defendible:** una instancia compartida con acceso del cliente
"porque es más barato", esperando aislamiento que no existe.

**Cada instancia dedicada es un servidor dedicado**, que es exactamente el
producto que este kit acompaña.

---

## 6. Sobre los datos del cliente

| Dato | Dónde está | Quién lo respalda |
|---|---|---|
| Panel de Coolify (proyectos, recursos) | `/data/coolify` + base interna | Hefesto, con el kit |
| **Datos de la aplicación del cliente** | Volúmenes del servidor | **El cliente**, o Hefesto si está en el alcance |
| Credenciales y claves SSH | `/data/coolify/ssh/keys/` | Hefesto, pero son **del cliente** |
| `APP_KEY` | `/data/coolify/source/.env` | Hefesto, con copia para el cliente |

**El punto que más distorsiona las cotizaciones:** respaldar el panel **no**
respalda los datos de la aplicación. Upstream lo dice sin ambigüedad. Si el
cliente cree que "el VPS tiene respaldos" y su base de datos se pierde, la
discusión va a ser cara.

Si el respaldo de los datos de la aplicación no está en el alcance, **decirlo
por escrito en la propuesta**.

---

## 7. Precios y Alias de referencia

Este kit no fija precios. Lo que sí entrega son los insumos para cotizar:

| Insumo | Dato verificado |
|---|---|
| Servidor mínimo para el panel | 2 vCPU, 2 GB RAM, 10 GB de disco |
| Servidor cómodo para panel + una app | 4 vCPU, 8 GB RAM, 60 GB (decisión de Hefesto) |
| Horas de instalación inicial | Cronometrar en el primer despliegue real |
| Costo mensual de operación | A definir según SLA y cobertura |
| Costo de un servidor dedicado por cliente | El que cobre el proveedor |

Los costos de **servidor y dominio los paga el cliente** y no son margen de
Hefesto. Decirlo desde la primera reunión evita la decepción después.

---

## 8. Qué NO prometer — lista de control

Antes de mandar una propuesta, verificar que no diga ninguna de estas cosas:

- ❌ "Respaldo de todo lo que está en el servidor" (el panel sí; las apps, solo
  si están en alcance).
- ❌ "Alta disponibilidad" (una instancia en un servidor es un punto único de
  falla; el cliente puede pedir más, y se cotiza aparte).
- ❌ "Aislamiento entre clientes" si se usa una instancia compartida.
- ❌ "Compatible con Supabase" (no aplica: el panel usa su propio PostgreSQL).
- ❌ "El panel nunca se cae" (puede: es software en un servidor).
- ❌ "Sin límites de usuarios o recursos" (no hay límites de licencia, pero los
  límites son los del servidor).
- ❌ "Migramos a Odoo automáticamente" (no hay conector; ver
  [`09-EXPORTACION-O-TRASPASO.md`](09-EXPORTACION-O-TRASPASO.md)).

---

## 9. Qué sí se puede prometer

- ✅ El panel instalado, funcionando por dominio, con HTTPS y puertos
  innecesarios cerrados.
- ✅ Respaldos automáticos, **verificados**, con al menos una restauración
  probada antes de dar por operativo el servicio.
- ✅ Actualizaciones controladas, no automáticas a ciegas.
- ✅ Bitácora de todo lo que se hace en el servidor.
- ✅ Que Hefesto responde, dentro del alcance contratado.

---

## 10. Pendiente de verificar

- No se cronometró una instalación real. Las horas de la sección 7 son un
  marcador de posición, no una promesa.
- No se evaluó la relación costo/beneficio de una instancia compartida con
  varios clientes: es una decisión de negocio de Hefesto, no un dato técnico.
