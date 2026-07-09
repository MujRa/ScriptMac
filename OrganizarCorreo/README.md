# Organizador de Correo para Apple Mail

Mueve automáticamente los correos **leídos** (entrada y salida) a carpetas
organizadas por dominio y dirección, sin repetir correos ya movidos.

Estructura resultante dentro de Mail, por cada cuenta:

```
gmail.com/
  Entrada/
    cliente1@gmail.com/
    cliente2@gmail.com/
  Enviado/
    cliente1@gmail.com/
hotmail.com/
  Entrada/
    proveedor@hotmail.com/
  Enviado/
```

## Archivos incluidos

- `OrganizarCorreo.applescript` → el programa (código fuente, editable con TextEdit o Script Editor)
- `com.usuario.organizarcorreo.plist` → la "receta" para que macOS lo ejecute solo cada cierto tiempo

---

## 1. Instalación (una sola vez)

1. Crea la carpeta donde vivirá el script:
   ```bash
   mkdir -p ~/OrganizarCorreo
   ```
2. Copia ahí el archivo `OrganizarCorreo.applescript` que descargaste.
   ```bash
   cp ~/Downloads/files/OrganizarCorreo.applescript .
   ```
3. Abre **Terminal** y dale permiso de ejecución (no es estrictamente
   necesario para `osascript`, pero deja todo ordenado):
   ```bash
   chmod +x ~/OrganizarCorreo/OrganizarCorreo.applescript
   ```

## 2. Primera prueba MANUAL (recomendado antes de automatizar)

1. Abre **Mail** y déjala abierta.
2. En Terminal, ejecuta:
   ```bash
   osascript ~/OrganizarCorreo/OrganizarCorreo.applescript
   ```
3. La primera vez macOS te va a pedir permiso:
   **"Terminal" quiere controlar "Mail"** → dale **Permitir**.
   (Esto se administra en _Ajustes del Sistema → Privacidad y Seguridad → Automatización_)
4. Espera a que termine. Si tienes muchos correos, Mail + AppleScript pueden
   tardar bastante (AppleScript es lento revisando buzones grandes).
5. Revisa en Mail que se hayan creado las carpetas por dominio y que los
   correos leídos se hayan movido correctamente.

**Recomendación:** prueba primero en una cuenta con pocos correos, o
haz un respaldo de tu buzón (Mail → Buzón → Exportar buzón...) antes de
correrlo sobre todo tu correo real.

## 3. Automatizarlo con launchd (para que corra solo)

macOS no usa `cron` de forma nativa recomendada; usa `launchd`.

1. Copia el archivo `com.usuario.organizarcorreo.plist` a:
   ```bash
   mkdir -p ~/OrganizarCorreo
   cp com.usuario.organizarcorreo.plist ~/Library/LaunchAgents/
   ```
2. **Edita el .plist** (con TextEdit o `nano`) y reemplaza `TU_USUARIO`
   por tu nombre de usuario real de Mac en las 3 rutas que aparecen:
   ```bash
   nano ~/Library/LaunchAgents/com.usuario.organizarcorreo.plist
   ```
   Tu nombre de usuario lo puedes ver con:
   ```bash
   whoami
   ```
3. Carga la tarea:
   ```bash
   launchctl load ~/Library/LaunchAgents/com.usuario.organizarcorreo.plist
   ```
4. Listo. Ahora correrá automáticamente cada 30 minutos (puedes cambiar
   ese valor, ver abajo) y también cada vez que inicies sesión en tu Mac.
   **Mail debe estar abierta** (o macOS la abrirá) para que funcione.

### Cambiar la frecuencia

Edita el `.plist` y cambia el número dentro de `<integer>1800</integer>`
(está en segundos). Por ejemplo:

- Cada 15 min → `900`
- Cada hora → `3600`
- Cada 6 horas → `21600`

Después de editar, recarga la tarea:

```bash
launchctl unload ~/Library/LaunchAgents/com.usuario.organizarcorreo.plist
launchctl load ~/Library/LaunchAgents/com.usuario.organizarcorreo.plist
```

### Ejecutarlo manualmente aunque esté automatizado

```bash
launchctl start com.usuario.organizarcorreo
```

### Ver si corrió y si hubo errores

```bash
cat ~/OrganizarCorreo/salida.log
cat ~/OrganizarCorreo/errores.log
```

### Desactivar la automatización

```bash
launchctl unload ~/Library/LaunchAgents/com.usuario.organizarcorreo.plist
```

---

## 4. Cómo editar el programa

El archivo `OrganizarCorreo.applescript` es texto plano. Puedes editarlo con:

- **Script Editor** (viene con macOS, búscalo con Spotlight: "Editor de Scripts" /
  "Script Editor"). Ahí puedes abrirlo, modificarlo y darle "Ejecutar" (▶) para
  probarlo directamente, con mejores mensajes de error que en Terminal.
- O con cualquier editor de texto (TextEdit en modo texto simple, VS Code, etc.)
  y luego correrlo con `osascript` como se explicó arriba.

### Partes que probablemente quieras ajustar:

- **Qué cuenta de correo revisar**: por defecto revisa TODAS las cuentas.
  Si quieres solo una, en el handler `run` cambia:
  ```applescript
  set listaCuentas to every account
  ```
  por, por ejemplo:
  ```applescript
  tell application "Mail" to set listaCuentas to {account "iCloud"}
  ```
- **Nombres de la carpeta de enviados**: si tu proveedor usa un nombre distinto
  a los ya contemplados (`Sent Messages`, `Sent`, `Enviados`, `Correo enviado`),
  agrégalo a esa lista dentro del handler `run`.
- **Reiniciar el control de "ya procesados"**: si quieres que vuelva a revisar
  todo desde cero, borra el archivo de registro:
  ```bash
  rm ~/Library/Application\ Support/OrganizarCorreo/procesados.txt
  ```

---

## 5. Notas importantes

- El script identifica cada correo por su **Message-ID** (el identificador
  único del correo), así que aunque lo muevas de carpeta, no se vuelve a
  procesar ni se duplica.
- Solo toca correos marcados como **leídos**. Los no leídos se dejan intactos
  hasta que los leas; en la siguiente corrida automática se moverán solos.
- AppleScript + Mail puede ser lento en buzones con miles de correos.
  Si notas que tarda mucho, considera correrlo con menos frecuencia
  (por ejemplo cada 6 horas) en vez de cada 30 minutos.
- No he podido probar este script en un Mac real desde aquí, así que
  pruébalo primero manualmente (paso 2) con pocos correos antes de dejarlo
  en automático.

## 6. Los correos ya estaban en el registro de "procesados".

- Si ya lo corriste antes (aunque no haya movido nada visible), pudo haber guardado IDs y ahora los salta. Puedes limpiar el registro con:
  ```bash
  rm ~/Library/Application\ Support/OrganizarCorreo/procesados.txt
  ```
