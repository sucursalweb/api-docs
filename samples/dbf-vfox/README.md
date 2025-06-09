# Proyecto Visual FoxPro 9: Sincronización con API de SucursalWeb

## 🚀 Uso (¡Empezá aquí!)

### Ejecución rápida:
1. Ejecuta el programa (el punto de entrada es el procedimiento `Main` que se ejecuta automáticamente).
2. Para ejecutar el programa manualmente, usa:
   ```foxpro
   DO SyncProducts
   ```

### Configuración inicial obligatoria:
1. Abre `SyncProducts.prg` en Visual FoxPro 9.
2. **IMPORTANTE:** Modifica las variables de configuración requeridas en el procedimiento `Main`:

   **A) Credenciales de SucursalWeb (proporcionadas por SucursalWeb):**
   ```foxpro
   * En el procedimiento Main, busca estas líneas y reemplaza los valores:
   gcTenant = "mi-tenant-id"                  && Reemplaza con tu Tenant real
   gcApiKey = "mi-api-key-secreto"            && Reemplaza con tu Api-Key secreto
   ```

   **B) Rutas de archivos DBF (configuradas por el desarrollador):**
   ```foxpro
   * Ajusta estas rutas según la ubicación de tus archivos DBF:
   gcArticuloPath = "/samples/dbf-vfox/data/ARTICULO.DBF"  && Ruta a tu DBF de productos
   gcTablasPath = "/samples/dbf-vfox/data/TABLAS.DBF"      && Ruta a tu DBF de tablas
   ```

### Configuración opcional:
Puedes ajustar otros parámetros según tus necesidades:
```foxpro
* Configuración de procesamiento
gnBatchSize = 200                              && Tamaño de lote (productos por envío)
gnIvaRate = 1.21                               && Multiplicador de IVA (21%)

* Archivos de salida
gcLogFile = "/samples/dbf-vfox/synclog.txt"    && Archivo de log
```

**Cambio de estrategia de deduplicación:**
El programa incluye tres estrategias SQL para manejar productos duplicados (FIRST, LAST, HIGHEST_PRICE). La estrategia FIRST está activa por defecto y es la recomendada para la mayoría de casos. Si necesitas una estrategia diferente, edita el código en la función `PrepareProducts()` comentando/descomentando las secciones SQL apropiadas. Ver la sección "Sistema de Deduplicación SQL" para detalles completos.

## ⚡ Novedades en esta versión

Esta versión incluye mejoras significativas sobre la implementación original:

- **🔄 Sistema de deduplicación SQL directo**: Maneja productos duplicados con 3 estrategias SQL eficientes
- **🛠️ Herramientas de debugging integradas**: Funciones para diagnosticar y resolver problemas con archivos DBF
- **⚡ Rendimiento optimizado**: Almacenamiento basado en strings para mejor manejo de memoria  
- **🔧 Limpieza automática**: Sistema robusto de limpieza de archivos DBF en caso de errores
- **📊 Configuración centralizada**: Variables globales en lugar de constantes para mayor flexibilidad
- **🚀 Arquitectura simplificada**: Eliminación de código legacy y enfoque en SQL directo

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

- Lee productos desde una ruta configurable de DBF (por defecto: `/samples/dbf-vfox/data/ARTICULO.DBF`).
- Sincroniza con la API v2 de SucursalWeb, siguiendo los 4 pasos principales.
- Procesa productos en lotes de 200 en el Paso #2.
- Aplica cálculo de IVA (21% por defecto) sobre los precios.
- Utiliza `WinHttp.WinHttpRequest.5.1` para las solicitudes HTTP.
- Implementa manejo de errores y registro de logs para mejor seguimiento.
- **NUEVO**: Sistema de deduplicación SQL directo con 3 estrategias configurables (FIRST, LAST, HIGHEST_PRICE).
- **NUEVO**: Herramientas de debugging integradas para manejo de archivos DBF.
- **NUEVO**: Almacenamiento optimizado de productos basado en strings para mejor rendimiento.
- **NUEVO**: Sistema robusto de limpieza automática de archivos DBF en caso de errores.
- **NUEVO**: Arquitectura simplificada sin código legacy de deduplicación en memoria.

## Estructura del programa

El programa está organizado en un módulo principal con punto de entrada explícito y varios procedimientos de apoyo:

### Procedimientos principales:
- `PROCEDURE Main`: Punto de entrada principal que coordina el flujo completo de sincronización
- `FUNCTION PrepareProducts`: Prepara la lista de productos desde el archivo DBF con deduplicación SQL
- `PROCEDURE UploadProductBatches`: Sube los productos en lotes
- `PROCEDURE InitSync`: Inicializa la sincronización y obtiene el ID (Paso 1)
- `PROCEDURE UploadBatch`: Sube un lote de productos (Paso 2)
- `PROCEDURE RequestSync`: Solicita la sincronización (Paso 3)
- `PROCEDURE GetSyncStatus`: Obtiene el estado de la sincronización (Paso 4)

### Funciones de utilidad:
- `FUNCTION CheckInternetConnection`: Verifica conectividad antes de iniciar
- `FUNCTION ExtractProductsFromRange`: Extrae lotes de productos de manera eficiente
- `FUNCTION BuildProductsJsonFromList`: Construye JSON desde la lista de productos
- `FUNCTION LookupTablas`: Busca descripciones en TABLAS.DBF
- `FUNCTION FindFieldByPattern`: Encuentra campos por patrón (ACTIVO/WEB)
- `FUNCTION RecordMatchesCriteria`: Verifica si un registro cumple los criterios
- `FUNCTION VerifyNoDuplicates`: Verifica la ausencia de duplicados en la lista final

### Herramientas de debugging:
- `PROCEDURE ForceCloseAllDbfs`: Cierra todos los archivos DBF forzadamente
- `PROCEDURE EmergencyDbfCleanup`: Limpieza de emergencia de archivos DBF
- `PROCEDURE HandleDbfError`: Maneja errores específicos de DBF
- `FUNCTION ReportOpenDbfs`: Reporta y cuenta archivos DBF abiertos

### ¿Por qué usamos lotes (batches)?

En las aplicaciones VFP tradicionales, cuando trabajamos con grandes cantidades de registros, solemos procesarlos todos de una vez porque estamos trabajando en la misma computadora. Sin embargo, al enviar datos por Internet a una API, este enfoque puede fallar por varias razones:

1. **Límites de tiempo**: Las conexiones web tienen tiempos límite. Enviar 5000 productos de una vez podría llevar tanto tiempo que la conexión se corta antes de terminar.

2. **Límites de memoria**: Construir un JSON enorme con miles de productos podría agotar la memoria disponible tanto en tu programa VFP como en el servidor que lo recibe.

3. **Recuperación ante errores**: Si enviás 5000 productos de una vez y ocurre un error en el producto 4999, perdés todo el trabajo. Con lotes, si falla el lote 25, solo necesitás reintentar ese lote.

4. **Control del progreso**: Los lotes te permiten mostrar al usuario un progreso real (ej: "Lote 5 de 25 completado").

Por estas razones, el procedimiento `UploadProductBatches` divide tu lista completa de productos en grupos más pequeños (por defecto, 200 productos por lote) y los envía secuencialmente. Es como enviar varias cajas pequeñas en lugar de un camión completo de mercadería.

## Sistema de Deduplicación SQL

El programa incluye un sistema de deduplicación basado en SQL para manejar productos duplicados (con el mismo CODIGO). Cuando tu archivo DBF contiene múltiples registros con el mismo código de producto, el sistema automáticamente selecciona uno de ellos según la estrategia configurada.

### Estrategias disponibles:

El código viene con tres estrategias pre-implementadas. La estrategia FIRST está activa por defecto, pero puedes elegir la que mejor se adapte a tu negocio:

#### **OPCIÓN 1: Primera ocurrencia (MIN RECNO)** - ACTIVA POR DEFECTO
```foxpro
SELECT CODIGO, MIN(RECNO()) as SelectedRecord ;
    FROM Articulos ;
    WHERE UPPER(ALLTRIM(&lcActivoField)) = 'S' ;
    AND UPPER(ALLTRIM(&lcWebField)) = 'S' ;
    AND !EMPTY(ALLTRIM(CODIGO)) ;
    GROUP BY CODIGO ;
    ORDER BY CODIGO ;
    INTO CURSOR UniqueProducts
```
**Conserva**: La primera ocurrencia encontrada de cada CODIGO  
**Ventajas**: Más rápida, simple y predecible  
**Recomendada para**: La mayoría de casos de uso

#### **OPCIÓN 2: Última ocurrencia (MAX RECNO)** - COMENTADA
```foxpro
SELECT CODIGO, MAX(RECNO()) as SelectedRecord ;
    FROM Articulos ;
    WHERE UPPER(ALLTRIM(&lcActivoField)) = 'S' ;
    AND UPPER(ALLTRIM(&lcWebField)) = 'S' ;
    AND !EMPTY(ALLTRIM(CODIGO)) ;
    GROUP BY CODIGO ;
    ORDER BY CODIGO ;
    INTO CURSOR UniqueProducts
```
**Conserva**: La última ocurrencia encontrada de cada CODIGO  
**Ventajas**: Útil cuando los registros más recientes son mejores  
**Recomendada para**: Cuando los datos se actualizan por append

#### **OPCIÓN 3: Precio más alto (HIGHEST PRECIO1)** - COMENTADA
```foxpro
SELECT A.CODIGO, A.RECNO() as SelectedRecord, A.PRECIO1 ;
    FROM Articulos A ;
    WHERE UPPER(ALLTRIM(A.&lcActivoField)) = 'S' ;
    AND UPPER(ALLTRIM(A.&lcWebField)) = 'S' ;
    AND !EMPTY(ALLTRIM(A.CODIGO)) ;
    AND A.RECNO() = (SELECT TOP 1 B.RECNO() ;
                     FROM Articulos B ;
                     WHERE B.CODIGO = A.CODIGO ;
                     AND UPPER(ALLTRIM(B.&lcActivoField)) = 'S' ;
                     AND UPPER(ALLTRIM(B.&lcWebField)) = 'S' ;
                     ORDER BY B.PRECIO1 DESC) ;
    ORDER BY A.CODIGO ;
    INTO CURSOR UniqueProducts
```
**Conserva**: El registro con el PRECIO1 más alto para cada CODIGO  
**Ventajas**: Garantiza que se conserven los productos con mejor precio  
**Recomendada para**: Cuando el precio es el factor más importante

### Cómo elegir una estrategia diferente:

Si la estrategia FIRST (por defecto) no es la adecuada para tu caso, puedes elegir otra:

1. Abrir `SyncProducts.prg`
2. Buscar la sección "DEDUPLICATION STRATEGY OPTIONS" en `PrepareProducts()`
3. Comentar la estrategia FIRST actual (agregar `*` al inicio de las líneas)
4. Descoomentar la estrategia deseada (quitar `*` del inicio de las líneas)
5. Asegurarse de que solo UNA estrategia esté activa

**Ejemplo para usar la estrategia LAST en lugar de FIRST:**
```foxpro
* OPTION 1: First occurrence (MIN RECNO) - COMMENTED OUT
* SELECT CODIGO, MIN(RECNO()) as SelectedRecord ;
*     FROM Articulos ;
*     WHERE UPPER(ALLTRIM(&lcActivoField)) = 'S' ;
*     AND UPPER(ALLTRIM(&lcWebField)) = 'S' ;
*     AND !EMPTY(ALLTRIM(CODIGO)) ;
*     GROUP BY CODIGO ;
*     ORDER BY CODIGO ;
*     INTO CURSOR UniqueProducts

* OPTION 2: Last occurrence (MAX RECNO) - NOW ACTIVE
SELECT CODIGO, MAX(RECNO()) as SelectedRecord ;
    FROM Articulos ;
    WHERE UPPER(ALLTRIM(&lcActivoField)) = 'S' ;
    AND UPPER(ALLTRIM(&lcWebField)) = 'S' ;
    AND !EMPTY(ALLTRIM(CODIGO)) ;
    GROUP BY CODIGO ;
    ORDER BY CODIGO ;
    INTO CURSOR UniqueProducts
WriteLog("DEBUG PrepareProducts: Using LAST occurrence strategy (MAX RECNO)")
```

## Herramientas de Debugging para DBF

Si experimentas problemas con archivos DBF que quedan abiertos después de errores, el programa incluye herramientas de debugging automáticas que se ejecutan al inicio y funciones que puedes usar manualmente:

### Funciones automáticas:
- **Verificación inicial**: Al iniciar, el programa verifica automáticamente si hay archivos DBF abiertos
- **Limpieza inicial**: Si encuentra archivos abiertos, ejecuta limpieza automática  
- **Manejo de errores**: Cada operación DBF incluye manejo de errores y limpieza

### Funciones manuales disponibles:
Las siguientes funciones están disponibles durante la ejecución del programa:

```foxpro
ReportOpenDbfs()           && Ver qué archivos están abiertos y contarlos
ForceCloseAllDbfs()        && Cerrar todos los archivos DBF forzadamente  
EmergencyDbfCleanup()      && Limpieza de emergencia (método más robusto)
HandleDbfError()           && Manejo específico de errores DBF
```

**Ejemplo de uso cuando algo falla:**
1. Abrir ventana de comandos (Ctrl+F2)
2. Escribir: `EmergencyDbfCleanup()`
3. Presionar Enter

Estas funciones están disponibles automáticamente cuando ejecutas el programa y utilizan técnicas robustas para cerrar archivos incluso en situaciones de error.

## Optimizaciones de Rendimiento

### Almacenamiento de productos optimizado:
El programa utiliza un sistema de almacenamiento basado en strings en lugar de arrays para mejorar el rendimiento y reducir el uso de memoria:

- **Variables globales**: `gcProductList` (lista separada por comas) y `gnProductCount` (contador)
- **Ventajas**: 
  - Menor uso de memoria para grandes cantidades de productos
  - Procesamiento más eficiente de lotes
  - Mejor manejo de productos duplicados
  - Extracción rápida de rangos específicos

### Procesamiento en lotes mejorado:
- La función `ExtractProductsFromRange` permite extraer lotes específicos sin cargar toda la lista en memoria
- Validación automática de datos antes del envío
- Manejo robusto de errores que preserva el estado de la lista global
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
  "Brand": "MARCA",                  // Marca de TABLAS.DBF (TABLA=14)
  "Tags": [
    "CLASIFICACION",                             // Clasificación (TABLA=1, campo CLASIFICACION)
    "CATEGORIA",                        // Rubro (TABLA=2, campo CATEGORIA)
    "ETIQUETA"                     // Tag (TABLA=3, campo TAG)
  ],
  "IsNew": false,                        // Si NOVEDAD = 'S'
  "IsSale": false,                       // Si OFERTA = 'S'
  "IsUnavailable": false,                // Si PROXIMO = 'S'
  "IsEnabled": true,                     // Si WEB = 'S' y ACTIVO = 'S'
  "Pics": ["ag0108"],                    // Campo IMAGEN
  "Attachs": [],                          // Array vacío para adjuntos
  "Props": [],
  "Exclusions": []
}
```

## Sistema de Logs y Manejo de Errores

El programa implementa un sistema de registro de logs y manejo de errores robusto:

- El registro de logs es **completamente opcional** y puede activarse o desactivarse según necesidad.
- Cuando está habilitado, los mensajes de log se muestran en pantalla y se guardan en el archivo configurado.
- Cada entrada de log incluye un timestamp preciso para facilitar el seguimiento y análisis posterior.
- El sistema maneja errores con bloques TRY-CATCH en cada operación importante, evitando que un fallo detenga todo el proceso.
- Verifica la conexión a Internet antes de iniciar el proceso para evitar intentos fallidos.
- Muestra mensajes de error, advertencia e información con formato adecuado usando ventanas de mensaje nativas de VFP.
- **NUEVO**: Limpieza automática de archivos DBF en caso de errores inesperados.
- **NUEVO**: Herramientas de debugging integradas para diagnosticar problemas con archivos DBF.

### Configuración del sistema de logs:
```foxpro
* En el procedimiento Main
LOCAL llLogEnabled
llLogEnabled = .T.  && Cambiar a .F. para deshabilitar logs

* Archivo de log (variable global)
gcLogFile = "/samples/dbf-vfox/synclog.txt"  && Cambiar la ruta según necesidad
```

### Debugging avanzado:
El programa incluye verificaciones automáticas del estado de archivos DBF y limpieza en caso de errores:

```foxpro
* Estas funciones están disponibles durante la ejecución:
ReportOpenDbfs()           && Verificar archivos abiertos y contarlos
ForceCloseAllDbfs()        && Cerrar todos los archivos DBF forzadamente
EmergencyDbfCleanup()      && Limpieza de emergencia más robusta
HandleDbfError()           && Manejo específico de errores DBF
```

El registro está habilitado por defecto (`llLogEnabled = .T.`) pero puede desactivarse fácilmente cuando no sea necesario, como en entornos de producción donde se requiera mayor velocidad de ejecución.


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

## Notas Importantes

### Configuración obligatoria:
- **CRÍTICO**: Reemplaza los valores `gcTenant` y `gcApiKey` en el procedimiento `Main` con los datos reales de tu cuenta de SucursalWeb.

### Funcionalidades implementadas:
- El flujo completo de sincronización (inicialización, carga de lotes, solicitud y consulta de estado) ya está implementado.
- El programa aplica automáticamente el IVA (configurable, 21% por defecto) a los precios mediante la variable `gnIvaRate`.
- Sistema de deduplicación SQL directo con tres estrategias configurables (FIRST, LAST, HIGHEST_PRICE).
- Herramientas de debugging integradas para diagnóstico automático y manual de problemas con archivos DBF.
- Verificación automática y limpieza de archivos DBF al inicio del programa.
- Manejo robusto de errores con limpieza automática en cada operación DBF.

### Estructura de datos procesada:
La función procesa los campos de la estructura estándar de ARTICULO.DBF incluyendo:
- **Campos básicos**: CODIGO, DESCRIP, DETALLE
- **Precios**: PRECIO1 con IVA aplicado automáticamente
- **Variantes**:
  - Colores (C1-C9) como array en `Variants` con `Variant: "Color"`
  - Talles (T1-T9) como array en `Variants` con `Variant: "Talle"`
- **Campos de clasificación** (todos van dentro del array `Tags`):
  - Marca/Brand (TABLAS.DBF con TABLA=14)
  - Rubros/Category (TABLAS.DBF con TABLA=13, campo RUBRO)
  - Etiquetas/Tags (TABLAS.DBF con TABLA=15, campo VIRTUAL)
  - Clasificaciones/Classification (TABLAS.DBF con TABLA=16, campo CATEGORIA)
- **Estados booleanos**:
  - IsNew: Si NOVEDAD = 'S'
  - IsSale: Si OFERTA = 'S'
  - IsUnavailable: Si PROXIMO = 'S'
  - IsEnabled: Si WEB = 'S' y ACTIVO = 'S'
- **Multimedia**:
  - Pics: Array con campo IMAGEN
  - Attachs: Array vacío para adjuntos

### Recomendaciones:
- La estrategia de deduplicación FIRST (primera ocurrencia) está activa por defecto y es recomendada para la mayoría de casos por su velocidad y simplicidad.
- Si necesitas una estrategia diferente, edita el código SQL en `PrepareProducts()` según se detalla en la sección "Sistema de Deduplicación SQL".
- Considera LAST si los registros más recientes son mejores, o HIGHEST_PRICE si el precio es el factor más importante.
- Prueba el flujo completo con un conjunto pequeño de productos antes de sincronizar todo tu catálogo.
- Mantén habilitado el sistema de logs durante las pruebas iniciales para facilitar el diagnóstico.
- El programa incluye verificación automática de archivos DBF al inicio, pero si experimentas problemas, usa `EmergencyDbfCleanup()` desde la ventana de comandos.