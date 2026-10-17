# 04 — Primera cuenta y usuarios

Acceder al panel con una cuenta nueva es el punto donde más se resuelve mal un
servidor: una cuenta weak que queda como administrador permanente, un token que
nadie rota, un panel abierto a internet. Este documento es el procedimiento
seguro.

---

## 1. Antes de crear la primera cuenta

### 1.1 No expongas el panel a internet todavía

Al terminar la instalación, el panel queda en `http://<ip-del-servidor>:8000`.
En ese momento **cualquiera que conozca la IP puede llegar a la pantalla de
registro**.

Orden recomendado:

1. Crear la primera cuenta **desde la red de confianza**: por SSH con túnel
   local, o restringiendo temporalmente el puerto a la IP del operador.
2. Recién después configurar el dominio y el HTTPS.
3. Cerrar `8000`, `6001` y `6002` al público (ver
   [`02-INSTALACION-COOLIFY.md`](02-INSTALACION-COOLIFY.md), sección 5.2).

### 1.2 Túnel SSH: la forma segura de crear la cuenta

Desde el equipo del operador, en una terminal:

```bash
ssh -L 8000:127.0.0.1:8000 usuario@<IP-DEL-SERVIDOR>
```

Y en el navegador: `http://127.0.0.1:8000`.

El panel queda accesible solo desde tu máquina y por el canal SSH, sin abrir el
puerto 8000 al mundo. Es lo que se hace en una caída de producción con clientes
esperando.

---

## 2. Crear la primera cuenta

El instalador oficial deja configurados `ROOT_USERNAME`, `ROOT_USER_EMAIL` y
`ROOT_USER_PASSWORD`, y el panel los usa para la cuenta inicial.

Si esos valores se pierden o no se anotaron, no hay un atajo documentado por upstream
para volver a definirlos desde cero sin tocar el `.env`. En ese caso el camino es
entrar al servidor por SSH: con túnel o desde el propio servidor, abre
`http://127.0.0.1:8000` localmente (por túnel o desde el propio servidor) y crea
la cuenta desde la interfaz.

**Reglas para la contraseña de la cuenta inicial:**

- Única, larga, generada (`openssl rand -base64 24` sirve).
- **No** reutilizada desde ningún gestor de contraseñas del equipo.
- Anotada en el gestor de contraseñas del cliente, no en un ticket.

**Anotar el `APP_KEY` en el mismo momento.** Es el paso que más se posterga y el
que más cuesta recuperar:

```bash
sudo grep '^APP_KEY=' /data/coolify/source/.env
```

Copia la línea completa a un gestor de contraseñas **fuera de este servidor**.

---

## 3. Cerrar el registro

Una instancia de Coolify no es un SaaS multiusuario: es el panel de
operación de los servidores de un cliente. La pregunta correcta no es "cierro el
registro" como en un sitio web, sino **quién puede crear cuentas y con qué
permisos**.

Después de crear la primera cuenta:

1. **Revisa los usuarios existentes** en el panel y elimina o degrada las cuentas
   que no correspondan.
2. **No invites al cliente a crear su propia cuenta** hasta que esté decidido el
   modelo de permisos (sección 4).
3. **No expongas el panel en `http://` a internet.** Con el puerto 8000 abierto
   al mundo y sin TLS, las credenciales viajan en claro.

> Sobre el registro abierto: la documentación de este kit **no verificó** un
> interruptor global de "registro cerrado" en la versión v4.4.6. Si el panel de
> tu instancia muestra uno, úsalo y documéntalo en la bitácora. Lo que sí es
> verificable y suficiente es el control de quién puede crear cuentas y con qué
> permisos. Queda anotado como pendiente en
> [`07-PRUEBAS-DE-ACEPTACION.md`](07-PRUEBAS-DE-ACEPTACION.md).

---

## 4. El límite de responsabilidad: Coolify no es multi-tenant

Esto hay que entenderlo bien antes de dar acceso a un cliente.

**Una instancia de Coolify administra los servidores de un cliente.** Coolify se
conecta a esos servidores por SSH y los opera. No es un servicio de hosting
multiusuario: **no existe aislamiento entre los servidores de clientes
diferentes dentro de una misma instancia.**

### 4.1 Qué pasa si Hefesto opera muchos clientes en una instancia

Es posible técnicamente: registrar los servidores de varios clientes en el mismo
panel. Pero hay que entender qué significa:

| Aspecto | Realidad |
|---|---|
| **Acceso** | Cualquiera con acceso al panel ve **todos** los servidores registrados, de todos los clientes |
| **Permisos** | Coolify tiene roles y permisos, pero un administrador ve todo el conjunto |
| **Aislamiento de datos** | No hay aislamiento fuerte entre clientes: misma instancia, mismos operadores |
| **Qué ve un cliente** | Si se le da una cuenta con permisos limitados, ve lo que ese rol permita — **no** lo que el cliente debería ver por contrato |

**Consecuencia práctica:** dar acceso al panel a un cliente implica darle
visibilidad sobre la operación de otros clientes. Eso no es un detalle: es una
decisión de seguridad y, muy probablemente, un problema de contrato.

### 4.2 Las dos salidas sensatas

**Opción A — una instancia por cliente (recomendada).**
Cada cliente tiene su panel, sus credenciales, sus respaldos. Es lo que la
documentación de upstream da por sentado: la instancia administra los servidores
de un cliente. Aísla de verdad y hace la operación predecible.

**Opción B — una instancia compartida administrada solo por Hefesto.**
Todos los clientes quedan detrás de la operación de Hefesto, sin acceso al
panel. Entonces hay que:

- No crear cuentas de cliente en esa instancia.
- Definir por escrito qué ve el cliente: relatórios, no panel.
- Asumir que una comprometimiento de esa instancia afecta a **todos** los
  clientes a la vez.

**Lo que no se debe hacer:** abrir una instancia compartida "para ahorrar
servidores" y dar acceso a los clientes creyendo que están aislados. No lo están.

---

## 5. Roles y permisos

Coolify maneja **roles y permisos** dentro de la instancia. El detalle de la
documentación upstream de esta sección debe revisarse en el panel de la versión
instalada, porque la interfaz cambia entre versiones.

Criterio de Hefesto para asignar roles:

| Persona | Rol razonable | Motivo |
|---|---|---|
| Administrador de Hefesto | Control total | Opera la instancia |
| Segunda persona de Hefesto | Control total (mínimo dos personas) | Que una persona no sea punto único de falla |
| Personal del cliente | **Sin acceso al panel**, o lectura muy acotada | El panel expone toda la operación |
| Integraciones (CI, webhooks) | Token de API con permiso mínimo | Solo lo que necesita |

Sobre los **tokens de API**: un token es una credencial de pleno acceso para lo
que su permiso permita. Crear un token con permiso amplio para automatizar algo
que solo necesita leer es abrir una puerta de más.

```bash
# Ejemplo de verificación (solo lectura) contra la instancia
curl --header "Authorization: Bearer $COOLIFY_TOKEN" \
     "$COOLIFY_URL/api/v1/version"
```

---

## 6. Claves SSH

Coolify se conecta a los servidores por SSH. La primera vez genera claves en
`/data/coolify/ssh/keys/`, y `~/.ssh/authorized_keys` del usuario del servidor
tiene la contraparte.

Implicaciones que hay que decírsele al cliente:

- **Quien tenga acceso al panel puede usar esas claves para entrar a los
  servidores.** Es una de las razones para no compartir el panel.
- Esas claves **son datos que hay que respaldar**, y son el motivo por el que la
  página de restauración de upstream pide también
  `/data/coolify/ssh/keys/` y `~/.ssh/authorized_keys`.

---

## 7. Lista de verificación de cierre

- [ ] Primera cuenta creada con contraseña única y anotada en un gestor.
- [ ] `APP_KEY` extraído y guardado fuera del servidor.
- [ ] Cuentas de prueba o sobrantes eliminadas o degradadas.
- [ ] Dominio y HTTPS configurados; el panel carga por `https://`.
- [ ] Puertos `8000`, `6001` y `6002` cerrados al público.
- [ ] Decidido el modelo: instancia por cliente o panel solo para Hefesto.
- [ ] Nadie del cliente con acceso al panel sin acuerdo explícito por escrito.

---

## 8. Pendiente de verificar

- No se verificó la existencia de un interruptor global de "registro cerrado" en
  la versión v4.4.6.
- No se documentó el detalle de roles y permisos de la interfaz actual: hay que
  leerlo en la versión instalada. No se inventa aquí una lista de roles.
- No se probó el flujo de "olvidé mi contraseña" del administrador del panel.
