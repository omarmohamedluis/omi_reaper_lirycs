# Instrucciones: Sistema Reaper <-> Google Sheets

Este sistema te permite trabajar directamente con **Google Sheets** y **Google Drive**, sin usar CSVs manuales.

## ¿Qué hace?
1.  **Importar (`Import_from_Drive.lua`)**:
    - Le das un **Enlace de Google Drive**.
    - El script **descarga automáticamente** el archivo `.wav` y lo pone en el Track 1.
    - Lee la **Hoja de Cálculo** (Google Sheet) de esa carpeta y crea las regiones en Reaper.
2.  **Exportar (`Export_to_Drive.lua`)**:
    - Si mueves o cambias las regiones en Reaper, ejecutas este script.
    - Actualiza automáticamente la Hoja de Cálculo en la nube con los nuevos tiempos.

## Configuración Inicial (Solo una vez)
Si no lo has hecho aún, sigue los pasos de `SETUP_GOOGLE.md` para crear tu archivo `credentials.json` y autorizar tu email.

## Cómo usarlo

### Paso 1: Importar
1.  Abre Reaper.
2.  Ejecuta la acción `Import_from_Drive.lua`.
3.  Pega el **Enlace de la carpeta de Google Drive** (ej: `https://drive.google.com/...`).
4.  Espera unos segundos. El script descargará el audio y creará las regiones.

### Paso 2: Editar
- Mueve las regiones, ajusta los tiempos, renómbralas si quieres.

### Paso 3: Guardar cambios (Exportar)
1.  Ejecuta la acción `Export_to_Drive.lua`.
2.  El script actualizará las columnas **L (Inicio)** y **M (Final)** de tu Google Sheet original.

## Notas
- El archivo `.wav` se descarga en la misma carpeta donde están los scripts.
- Asegúrate de que en la carpeta de Drive solo haya **un** archivo `.wav` y **un** Google Sheet para evitar confusiones.
