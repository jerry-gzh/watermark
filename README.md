# Agrega marca de agua a fotos por lotes 

Esta es una aplicacion basica pero poderosa para establecer una marca de agua en fotos por lotes.

# Documentacion de la aplicacion (Automator)

Esta guia explica como crear y usar la app en Automator con el script `watermark.sh`.

## Requisitos

- macOS
- ImageMagick instalado

Para instalar ImageMagick:

```sh
brew install imagemagick
```

Si no tienes Homebrew, sigue las instrucciones en https://brew.sh

## Crear la aplicacion en Automator

1) Abre **Automator**.
2) Elige **Nuevo documento**.
3) Selecciona **Aplicacion** y presiona **Elegir**.
4) En la barra de acciones, busca **Run AppleScript** (o **Ejecutar AppleScript**).
5) Arrastra **Run AppleScript** al panel derecho.
6) Borra el contenido por defecto del bloque.
7) Abre el archivo `watermark.sh` y copia todo su contenido.
8) Pega el contenido en el bloque de **Run AppleScript**.
9) Guarda la app: **Archivo > Guardar...** y elige una carpeta (por ejemplo, Aplicaciones).

## Uso basico

1) Abre la app creada.
2) Selecciona las imagenes a procesar.
3) Selecciona el logo (PNG con fondo transparente).
4) Ajusta parametros (tamano, opacidad, margen, calidad) y la posicion.
5) Se abre una previsualizacion de la primera imagen:
   - Presiona **Aceptar** para continuar.
   - Presiona **Modificar** para volver a ajustar parametros.
6) Selecciona la carpeta destino.
7) Se procesa el lote y se muestra el resumen en la ventana final.

## Comportamientos utiles

- Cada selector recuerda la ultima carpeta usada (imagenes, logo, destino).
- Si esa carpeta ya no existe, se abre el selector en la ubicacion por defecto.
- La previsualizacion usa Quick Look y se cierra al aceptar o modificar.
- El log solo se crea si hay errores.

## Dudas frecuentes

### "No encontre ImageMagick (magick)"
Instala ImageMagick con:

```sh
brew install imagemagick
```

### La previsualizacion no aparece
Puede requerir permisos de automatizacion. Ve a:
**Preferencias del Sistema > Seguridad y privacidad > Privacidad**
y habilita Automator para controlar Quick Look/Preview si aplica.

### Donde se guarda el log
En el escritorio, como `watermark_app_log.txt`. Solo se crea si hubo errores.

## Archivos

- Script principal: `watermark.sh`
- Documento: `DOCUMENTACION.md`
