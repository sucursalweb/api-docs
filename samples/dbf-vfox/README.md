# Proyecto Visual FoxPro 9: Sincronización con API de SucursalWeb

## Resumen para Desarrolladores VFP

¡Buenas noticias! Este programa se encarga de toda la complejidad técnica para que vos puedas sincronizar tus productos con SucursalWeb de manera simple.

**No necesitás aprender nada nuevo** para usar este código. El programa maneja automáticamente todas las partes técnicas:
- La conexión a internet
- La estructura de los datos
- El envío en lotes
- Los reintentos en caso de errores

**Para usarlo, simplemente:**
1. Completá tus datos de conexión (tu Tenant y Api-Key)
2. Ajustá las rutas a tus archivos DBF si es necesario
3. Probá el programa con algunos productos
4. Cuando funcione, integralo en tu aplicación principal

El programa lee tus tablas de productos (ARTICULO.DBF) y referencias (TABLAS.DBF), envía los datos a SucursalWeb, y te avisa cuando termina. Los mensajes en pantalla te muestran el progreso paso a paso.

Todo está diseñado para funcionar directamente sin necesidad de instalar nada más en Windows. El código incluye comentarios claros y manejo de errores para que sepas qué hacer si algo no funciona como esperás.

## Características principales

Este proyecto demuestra cómo leer productos desde un archivo DBF y sincronizarlos con la API v2 de SucursalWeb usando Visual FoxPro 9. Las operaciones HTTP se realizan mediante el objeto COM `WinHttp.WinHttpRequest.5.1`.

- Lee productos desde una ruta configurable de DBF (por defecto: `/data/ARTICULO.DBF`).
- Sincroniza con la API v2 de SucursalWeb, siguiendo los 4 pasos principales.
- Procesa productos en lotes de 200 en el Paso #2.
- Aplica cálculo de IVA (21% por defecto) sobre los precios.
- Utiliza `WinHttp.WinHttpRequest.5.1` para las solicitudes HTTP.
- Implementa manejo de errores y registro de logs para mejor seguimiento.

## Estructura del programa

El programa está organizado en un módulo principal con punto de entrada explícito y varios procedimientos de apoyo:

- `PROCEDURE Main`: Punto de entrada principal que coordina el flujo completo de sincronización
- `PROCEDURE PrepareProducts`: Prepara la lista de productos desde el archivo DBF
- `PROCEDURE UploadProductBatches`: Sube los productos en lotes
- `PROCEDURE InitSync`: Inicializa la sincronización y obtiene el ID (Paso 1)
- `PROCEDURE UploadBatch`: Sube un lote de productos (Paso 2)
- `PROCEDURE RequestSync`: Solicita la sincronización (Paso 3)
- `PROCEDURE GetSyncStatus`: Obtiene el estado de la sincronización (Paso 4)

### ¿Por qué usamos lotes (batches)?

En las aplicaciones VFP tradicionales, cuando trabajamos con grandes cantidades de registros, solemos procesarlos todos de una vez porque estamos trabajando en la misma computadora. Sin embargo, al enviar datos por Internet a una API, este enfoque puede fallar por varias razones:

1. **Límites de tiempo**: Las conexiones web tienen tiempos límite. Enviar 5000 productos de una vez podría llevar tanto tiempo que la conexión se corta antes de terminar.

2. **Límites de memoria**: Construir un JSON enorme con miles de productos podría agotar la memoria disponible tanto en tu programa VFP como en el servidor que lo recibe.

3. **Recuperación ante errores**: Si enviás 5000 productos de una vez y ocurre un error en el producto 4999, perdés todo el trabajo. Con lotes, si falla el lote 25, solo necesitás reintentar ese lote.

4. **Control del progreso**: Los lotes te permiten mostrar al usuario un progreso real (ej: "Lote 5 de 25 completado").

Por estas razones, el procedimiento `UploadProductBatches` divide tu lista completa de productos en grupos más pequeños (por defecto, 200 productos por lote) y los envía secuencialmente. Es como enviar varias cajas pequeñas en lugar de un camión completo de mercadería.
- Funciones de apoyo para construir el JSON de productos y sus variantes
- Sistema de registro de logs y manejo de errores integrado

## Pasos principales del proceso de sincronización
1. Inicializar y obtener un Identificador que te sirve para el resto de las operaciones.
2. Subir un lote (si tenés miles de productos, se recomienda crear lotes de 200 y subirlos uno detrás del otro. Por ejemplo: si tenés 5000 productos, subís 25 lotes de 200 productos cada uno).
3. Solicitar una Sincronización.
4. Obtener el estado de la Sincronización (poll).

## Estructura JSON de los productos

Los productos se envían a la API en formato JSON con la siguiente estructura:

```json
{
  "Code": "CODIGO",
  "Name": "DESCRIP",
  "Details": "DETALLE",
  "Prices": [
    {
      "Price": 12345.67,  // PRECIO1 * 1.21 (IVA del 21%)
      "SalePrice": 0
    }
  ],
  "Variants": [
    {
      "Variant": "Color",
      "OrderedList": ["bco", "nat", "negro", ...]  // C1-C9
    },
    {
      "Variant": "Talle",
      "OrderedList": ["95", "100", "105", ...]     // T1-T9
    }
  ],
  "Brand": "ANA GRANT",                  // Marca de TABLAS.DBF (TABLA=14)
  "Tags": [
    "MUJER",                             // Clasificación (TABLA=16, campo CATEGORIA)
    "CORSETERIA",                        // Rubro (TABLA=13, campo RUBRO)
    "PROMO INVIERNO"                     // Tag (TABLA=15, campo VIRTUAL)
  ],
  "IsNew": false,                        // Si NOVEDAD = 'S'
  "IsSale": false,                       // Si OFERTA = 'S'
  "IsUnavailable": false,                // Si PROXIMO = 'S'
  "IsEnabled": true,                     // Si WEB = 'S' y ACTIVO = 'S'
  "Pics": ["ag0108"],                    // Campo IMAGEN
  "Attachs": []                          // Array vacío para adjuntos
}
```

## Uso
1. Abre `SyncProducts.prg` en Visual FoxPro 9.
2. **IMPORTANTE:** Modifica las constantes `TU_TENANT` y `TU_API_KEY` al inicio del código con los valores que te proporcionó SucursalWeb:
   ```foxpro
   #DEFINE TU_TENANT "tu-tenant-real-aqui"        && Reemplaza con tu Tenant 
   #DEFINE TU_API_KEY "tu-api-key-real-aqui"      && Reemplaza con tu Api-Key
   ```
3. Ajusta la ruta del DBF y el multiplicador de IVA según sea necesario.
4. Ejecuta el programa (el punto de entrada es el procedimiento `Main` que se ejecuta automáticamente).

Para ejecutar el programa manualmente, usa:
```foxpro
DO SyncProducts
```

El programa automáticamente llama al procedimiento `Main` como punto de entrada.

## Sistema de Logs y Manejo de Errores

El programa implementa un sistema de registro de logs y manejo de errores robusto:

- El registro de logs es **completamente opcional** y puede activarse o desactivarse según necesidad.
- Cuando está habilitado, los mensajes de log se muestran en pantalla y se guardan en el archivo `synclog.txt`.
- Cada entrada de log incluye un timestamp preciso para facilitar el seguimiento y análisis posterior.
- El sistema maneja errores con bloques TRY-CATCH en cada operación importante, evitando que un fallo detenga todo el proceso.
- Verifica la conexión a Internet antes de iniciar el proceso para evitar intentos fallidos.
- Muestra mensajes de error, advertencia e información con formato adecuado usando ventanas de mensaje nativas de VFP.

Para habilitar o deshabilitar el registro de logs:
```foxpro
* En el procedimiento Main
llLogEnabled = .T.  && Cambiar a .F. para deshabilitar logs
```

Para modificar la ubicación del archivo de logs:
```foxpro
* Al inicio del archivo (constantes)
#DEFINE LOG_FILE "/samples/dbf-vfox/synclog.txt"  && Cambiar la ruta según necesidad
```

El registro está habilitado por defecto (`llLogEnabled = .T.`) pero puede desactivarse fácilmente cuando no sea necesario, como en entornos de producción donde se requiera mayor velocidad de ejecución. Si se mantiene habilitado, asegúrate de que la ruta definida en `LOG_FILE` sea accesible para escritura.


## Uso del objeto COM `WinHttp.WinHttpRequest.5.1`
Para realizar las operaciones HTTP, este proyecto utiliza el objeto COM `WinHttp.WinHttpRequest.5.1`, que viene incluido en la mayoría de las instalaciones de Windows modernas.

### ¿Qué es un objeto COM?
COM (Component Object Model) es una tecnología de Microsoft que permite que diferentes aplicaciones y lenguajes interactúen entre sí. En este caso, Visual FoxPro puede crear y usar objetos COM para acceder a funcionalidades del sistema operativo, como realizar solicitudes HTTP.

### ¿Cómo se usa en Visual FoxPro?
No es necesario instalar librerías adicionales si usás Windows 7 o superior, ya que `WinHttp.WinHttpRequest.5.1` viene preinstalado. El objeto se crea así:

```foxpro
loHttp = CREATEOBJECT("WinHttp.WinHttpRequest.5.1")
```

Luego, podés usar métodos como `.Open`, `.SetRequestHeader`, `.Send`, y propiedades como `.Status` y `.ResponseText` para interactuar con la API.

### ¿Qué hacer si da error?
Si al ejecutar `CREATEOBJECT("WinHttp.WinHttpRequest.5.1")` recibís un error como "OLE error code 0x80040154: Class not registered", significa que tu sistema no tiene registrado el componente. En la mayoría de los casos, esto se soluciona actualizando Windows o instalando [WinHTTP](https://support.microsoft.com/es-es/topic/description-of-the-winhttp-5-1-update-for-windows-7-and-windows-server-2008-r2-2b6b6b2d-2e2e-6e2e-2e2e-2e2e2e2e2e2e).

Si usás una versión de Windows muy antigua, podrías necesitar instalarlo manualmente. Consulta la documentación oficial de Microsoft para más detalles.

### Recursos útiles
- [Documentación oficial de WinHttpRequest (Microsoft)](https://learn.microsoft.com/en-us/windows/win32/winhttp/iwinhttprequest-interface)
- [Referencia de objetos COM en Visual FoxPro](https://learn.microsoft.com/en-us/previous-versions/visualstudio/foxpro/aa977276(v=vs.71))

---

## Notas
- Recuerda reemplazar los valores definidos como `TU_TENANT` y `TU_API_KEY` al inicio del código por los datos reales de tu cuenta.
- El flujo completo de sincronización (inicialización, carga de lotes, solicitud y consulta de estado) ya está implementado.
- El programa aplica automáticamente el IVA (21% por defecto) a los precios. Este multiplicador puede configurarse modificando la variable `lnIVA` en el procedimiento `Main`.
- La función procesa los campos de la estructura estándar de ARTICULO.DBF incluyendo:
  - Campos básicos (CODIGO, DESCRIP, DETALLE)
  - Precios (PRECIO1 con IVA aplicado)
  - Variantes:
    - Colores (C1-C9) como un array en `Variants` con `Variant: "Color"`
    - Talles (T1-T9) como un array en `Variants` con `Variant: "Talle"`
  - Campos de clasificación:
    - Marca/Brand (Tablas.dbf con TABLA=14)
    - Todos estos van dentro del array `Tags`:
      - Rubros/Category (Tablas.dbf con TABLA=13, campo RUBRO)
      - Etiquetas/Tags (Tablas.dbf con TABLA=15, campo VIRTUAL)
      - Clasificaciones/Classification (Tablas.dbf con TABLA=16, campo CATEGORIA)
  - Estados booleanos:
    - IsNew: Si NOVEDAD = 'S'
    - IsSale: Si OFERTA = 'S'
    - IsUnavailable: Si PROXIMO = 'S'
    - IsEnabled: Si WEB = 'S' y ACTIVO = 'S'
  - Imágenes y Adjuntos:
    - Pics: Array con IMAGEN
    - Attachs: Array vacío para adjuntos
- Se recomienda revisar y ajustar la configuración de error y log según las necesidades específicas de tu entorno.
- Prueba el flujo completo con un conjunto pequeño de productos antes de sincronizar todo tu catálogo.