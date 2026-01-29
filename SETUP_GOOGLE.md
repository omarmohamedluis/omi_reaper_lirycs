# Configuración de Google Sheets para Reaper

Para que los scripts funcionen, necesitamos configurar el acceso a Google.

## 1. Instalar Librerías de Python
Abre una terminal (PowerShell o CMD) y ejecuta:
```bash
pip install --upgrade google-api-python-client google-auth-httplib2 google-auth-oauthlib
```

## 2. Crear Credenciales de Google Cloud
**Paso A: Crear Proyecto**
1. Entra en [Google Cloud Console](https://console.cloud.google.com/).
2. Arriba a la izquierda, haz clic en el selector de proyectos y elige **"Nuevo Proyecto"**.
3. Ponle un nombre (ej: "Reaper Scripts") y dale a **Crear**.
4. Espera a que se cree y **selecciónalo**.

**Paso B: Habilitar APIs**
1. En el menú lateral, ve a **APIs y servicios** > **Biblioteca**.
2. Busca **"Google Drive API"** -> Clic -> **Habilitar**.
3. Vuelve a la Biblioteca, busca **"Google Sheets API"** -> Clic -> **Habilitar**.

**Paso C: Pantalla de Consentimiento (IMPORTANTE)**
*Antes de crear credenciales, Google te pide configurar esto.*
1. Ve a **APIs y servicios** > **Pantalla de consentimiento de OAuth**.
2. Selecciona **Externo** y dale a **Crear**.
3. Rellena solo lo obligatorio:
   - **Nombre de la aplicación**: "Reaper"
   - **Correo de asistencia**: Tu email.
   - **Información de contacto del desarrollador**: Tu email.
4. Dale a **Guardar y Continuar**.
5. **Paso "Usuarios de prueba" (CRUCIAL)**:
   - Haz clic en **+ ADD USERS**.
   - Escribe **tu propia dirección de correo** (la que vas a usar para loguearte).
   - Dale a **Guardar**.
6. Dale a **Guardar y Continuar** hasta terminar.
7. Vuelve al panel principal ("Volver al panel").

**Paso D: Crear las Credenciales (El archivo JSON)**
1. Ve a **APIs y servicios** > **Credenciales**.
2. Arriba, haz clic en **+ CREAR CREDENCIALES** > **ID de cliente de OAuth**.
3. **Tipo de aplicación**: Elige **Aplicación de escritorio**.
4. Nombre: Déjalo como está o pon "Script".
5. Dale a **Crear**.
6. Aparecerá una ventana con "Cliente creado". Haz clic en el botón de **DESCARGAR JSON** (icono de flecha hacia abajo).
7. **Renombra** ese archivo a `credentials.json`.
8. **Muévelo** a la carpeta `C:\Users\moruv\Desktop\rosalia lirycs\`.

## 3. Uso
### Importar (Drive -> Reaper)
1. Ejecuta `Import_from_Drive.lua` en Reaper.
2. Pega el enlace de la carpeta de Google Drive.
   - La primera vez, se abrirá el navegador para que inicies sesión en Google.

### Exportar (Reaper -> Drive)
1. Haz cambios en las regiones en Reaper.
2. Ejecuta `Export_to_Drive.lua`.
3. Se actualizarán los tiempos en la hoja de cálculo original.
