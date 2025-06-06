* Visual FoxPro 9 Project: Sync ARTICULO.DBF with SucursalWeb API v2
* Reads products from configurable DBF path (default: /data/ARTICULO.DBF)
* Follows 4 main sync steps, batching 200 products in Step #2
*
* === DEDUPLICATION STRATEGIES ===
* The script now handles duplicate CODIGO entries with configurable strategies:
* - "FIRST"   : Keep first occurrence, skip duplicates (default, fast)
* - "LAST"    : Keep last occurrence, replace previous  
* - "QUALITY" : Compare quality scores and keep the best version
* - "NONE"    : No deduplication (original behavior, may cause API errors)
* 
* Configure via: gcDedupeStrategy = "FIRST|LAST|QUALITY|NONE"
* Quality scoring considers: description length, price, images, variants, categories
*
*
* === DEBUGGING AYUDA ===
* Si los archivos DBF quedan abiertos después de un error, puedes usar estas funciones
* desde la ventana de comandos de VFP:
*
* CheckDbfStatus()        - Ver qué archivos están abiertos
* EmergencyCleanup()      - Cerrar todos los archivos DBF
* ForceClose("Alias")     - Cerrar un alias específico
*
* Ejemplo de uso:
* - Abrir ventana de comandos (Ctrl+F2)
* - Escribir: EmergencyCleanup()
* - Presionar Enter
* === FIN DEBUGGING AYUDA ===

* Configuration will be initialized inside Main procedure

* Global variables for product data instead of array
PUBLIC gcProductList  && Will hold comma-separated list of products
PUBLIC gnProductCount  && Count of products

DO Main

* Punto de entrada principal del programa
PROCEDURE Main
    * Initialize configuration variables first
    PUBLIC gcArticuloPath, gcTablasPath, gcApiBase, gnBatchSize, gnIvaRate
    PUBLIC gcTenant, gcApiKey, gcLogFile
    PUBLIC gcDedupeStrategy  && New: controls deduplication behavior
    
    * Initialize product data storage
    gcProductList = ""
    gnProductCount = 0

    * Data paths and constants 
    gcArticuloPath = "/samples/dbf-vfox/data/ARTICULO.DBF"  && Path to DBF with products
    gcTablasPath = "/samples/dbf-vfox/data/TABLAS.DBF"      && Path to lookup tables DBF
    gcApiBase = "https://api.sucursalweb.io/v2"             && API base URL
    gnBatchSize = 200                                       && Default batch size for uploads
    gnIvaRate = 1.21                                        && Multiplicador de IVA (21%)
    gcDebugFolder = "/samples/dbf-vfox/"                    && Folder for debug output files

    * Authentication and logging
    gcTenant = "mi-tenant-id"                               && Reemplaza con tu Tenant real
    gcApiKey = "mi-api-key-secreto"                         && Reemplaza con tu Api-Key secreto
    gcLogFile = "/samples/dbf-vfox/synclog.txt"             && Archivo de log
    
    * Deduplication strategy configuration
    * "FIRST"    - Keep first occurrence, skip duplicates (simple & fast)
    * "QUALITY"  - Compare duplicates and keep the best quality version
    * "LAST"     - Keep last occurrence (replace previous)
    * "NONE"     - No deduplication (original behavior - may cause API errors)
    gcDedupeStrategy = "FIRST"  && Default: simple first-wins strategy
    
    LOCAL llLogEnabled
    LOCAL llContinue  && Flag for early return conditions

    llLogEnabled = .T.  && Habilitar log
    llContinue = .T.    && Flag for flow control
    
    * Inicializar log
    IF llLogEnabled
        InitLog()
    ENDIF
    
    * === Startup cleanup - Ensure clean DBF state ===
    WriteLog("=== INICIO DE SESIÓN - VERIFICANDO ESTADO ===")
    LOCAL lnOpenFiles
    lnOpenFiles = ReportOpenDbfs()
    IF lnOpenFiles > 0
        WriteLog("ADVERTENCIA: Se encontraron " + TRANSFORM(lnOpenFiles) + " archivos DBF abiertos al inicio")
        WriteLog("Ejecutando limpieza inicial...")
        ForceCloseAllDbfs()
        * Verify cleanup worked
        IF ReportOpenDbfs() > 0
            WriteLog("ADVERTENCIA: Limpieza inicial no fue completamente exitosa")
            EmergencyDbfCleanup()
        ENDIF
    ELSE
        WriteLog("OK: No hay archivos DBF abiertos al inicio")
    ENDIF
    WriteLog("=== FIN VERIFICACIÓN INICIAL ===")
    * === End startup cleanup ===
    
    * Debug: Verificar estado inicial de los datos de productos
    WriteLog("INICIO: Verificando almacenamiento de productos después de InitLog")
    WriteLog("INICIO: gcProductList inicializado: '" + gcProductList + "'")
    WriteLog("INICIO: gnProductCount: " + TRANSFORM(gnProductCount))
    
    * Mostrar información inicial
    CLEAR
    WriteLog("=== Sincronización de Productos con SucursalWeb API v2 ===")
    WriteLog("DBF Origen: " + gcArticuloPath)  && Using global variable
    WriteLog("Tamaño de lote: " + TRANSFORM(gnBatchSize))  && Using global variable
    WriteLog("")
    
    * Verifica conexión a Internet antes de empezar
    IF .NOT. CheckInternetConnection()
        ShowError("No hay conexión a Internet. Verifique su conexión e intente nuevamente.")
        WriteLog("ERROR: No hay conexión a Internet")
        RETURN
    ENDIF

    TRY
        * Paso 1: Inicializar y obtener un Identificador
        WriteLog("Paso 1: Inicializando sincronización...")
        LOCAL lcApiBase, lcSyncId
        lcApiBase = gcApiBase  && Usando variable global
        lcSyncId = InitSync(lcApiBase)
        IF EMPTY(lcSyncId)
            ShowError("No se pudo inicializar la sincronización.")
            WriteLog("ERROR: No se pudo obtener un ID de sincronización")
            llContinue = .F.  && Set flag instead of RETURN
        ENDIF
        
        IF llContinue  && Only continue if we have a valid syncId
            WriteLog("- ID de Sincronización obtenido: " + lcSyncId)
            WriteLog("")

            * Paso 2: Leer productos del DBF y subir en lotes
            WriteLog("Paso 2: Preparando productos para sincronización...")
            * Trabajamos con variables globales para almacenar los productos
            
            * Usamos la variable global en lugar de la constante
            LOCAL lcArticuloPath
            lcArticuloPath = gcArticuloPath  && Variable global inicializada al comienzo
            
            LOCAL lnCount
            * Llamamos PrepareProducts que trabajará con las variables globales directamente
            lnCount = PrepareProducts(lcArticuloPath)
            
            * Debug: Verificar estado después de PrepareProducts
            WriteLog("Main: POST-PrepareProducts - Conteo: " + TRANSFORM(lnCount))
            WriteLog("Main: gcProductList length: " + TRANSFORM(LEN(gcProductList)))
            WriteLog("Main: gnProductCount: " + TRANSFORM(gnProductCount))
            
            * === DEBUG: Guardar lista de productos ===
            SaveDebugProductList()
            * === END DEBUG ===
            
            * Validar que tenemos productos para procesar
            IF lnCount <= 0 OR EMPTY(gcProductList)
                ShowError("No se encontraron productos para sincronizar.")
                WriteLog("ERROR: No se encontraron productos para sincronizar o hubo un error con el archivo DBF")
                llContinue = .F.  && Set flag instead of RETURN
            ELSE
                * Log información sobre los productos encontrados
                WriteLog("- " + TRANSFORM(lnCount) + " productos preparados.")
                WriteLog("- Lista de productos: " + LEFT(gcProductList, 100) + IIF(LEN(gcProductList) > 100, "...", ""))
                
                * === TEST: Verificar lógica de extracción con datos conocidos ===
                * TestExtractProductsFromRange()  && Commented out - function not implemented
                * === FIN TEST ===
            ENDIF
        ENDIF
        
        IF llContinue  && Only continue if we have products
            WriteLog("- " + TRANSFORM(lnCount) + " productos preparados.")
            WriteLog("")

            * Validación simple antes del upload
            IF llContinue AND gnProductCount > 0 AND !EMPTY(gcProductList)
                WriteLog("Subiendo productos en lotes...")
                LOCAL lnBatchSize
                lnBatchSize = gnBatchSize  && Usando variable global
                * Trabajamos con las variables globales directamente
                IF .NOT. UploadProductBatches(lcApiBase, lcSyncId, lnBatchSize)
                    ShowError("Error al cargar los lotes de productos.")
                    WriteLog("ERROR: Falló la carga de lotes de productos")
                    llContinue = .F.  && Set flag instead of RETURN
                ENDIF
            ELSE
                IF llContinue  && Only show error if we haven't already flagged an issue
                    ShowError("Los productos no están disponibles para la sincronización.")
                    WriteLog("ERROR: Productos no disponibles para sincronización")
                    WriteLog("DEBUG: gnProductCount: " + TRANSFORM(gnProductCount))
                    WriteLog("DEBUG: gcProductList length: " + TRANSFORM(LEN(gcProductList)))
                ENDIF
                llContinue = .F.  && Set flag instead of RETURN
            ENDIF
        ENDIF
        
        IF llContinue  && Only continue if products were uploaded successfully
            WriteLog("")

            * Paso 3: Solicitar la sincronización
            WriteLog("Paso 3: Solicitando sincronización al servidor...")
            IF .NOT. RequestSync(lcApiBase, lcSyncId)
                ShowError("No se pudo solicitar la sincronización.")
                WriteLog("ERROR: Falló la solicitud de sincronización")
                llContinue = .F.  && Set flag instead of RETURN
            ENDIF
        ENDIF
        
        IF llContinue  && Only continue if sync was requested successfully
            WriteLog("- Solicitud de sincronización enviada correctamente.")
            WriteLog("")

            * Paso 4: Obtener el estado de la sincronización (poll)
            WriteLog("Paso 4: Verificando estado de la sincronización...")
            LOCAL lcStatus
            lcStatus = GetSyncStatus(lcApiBase, lcSyncId)
            WriteLog("- Estado final: " + lcStatus)
            WriteLog("")
            
            * Mostrar resultado final
            IF lcStatus = "Completed"
                ShowInfo("Sincronización completada exitosamente.")
                WriteLog("ÉXITO: Proceso de sincronización completado")
            ELSE
                ShowWarning("Sincronización finalizada con estado: " + lcStatus)
                WriteLog("AVISO: Proceso de sincronización terminado con estado: " + lcStatus)
            ENDIF
        ENDIF
    
    CATCH TO loError
        * Manejo de errores general
        ShowError("Error inesperado: " + loError.Message)
        WriteLog("ERROR CRÍTICO: " + loError.Message)
        WriteLog("Línea: " + TRANSFORM(loError.LineNo))
        WriteLog("Detalles: " + loError.Details)
        
        * === Enhanced error handling with DBF reporting ===
        WriteLog("=== DIAGNÓSTICO POST-ERROR ===")
        ReportOpenDbfs()
        HandleDbfError("Main", loError)
        * === End enhanced error handling ===
    ENDTRY
    
    * === Final cleanup with reporting ===
    WriteLog("=== LIMPIEZA FINAL ===")
    ReportOpenDbfs()
    ForceCloseAllDbfs()
    * Verificar que todo se cerró correctamente
    IF ReportOpenDbfs() > 0
        WriteLog("ADVERTENCIA: Aún hay DBF abiertos después de la limpieza")
        EmergencyDbfCleanup()
    ENDIF
    WriteLog("=== FIN DE EJECUCIÓN ===")
    * === End final cleanup ===
ENDPROC

* Helper function to find field names that contain specific patterns
FUNCTION FindFieldByPattern(lcPattern)
    LOCAL i, lcFieldName, lcResult
    lcResult = ""
    
    FOR i = 1 TO FCOUNT()
        lcFieldName = FIELD(i)
        IF UPPER(lcPattern) $ UPPER(lcFieldName)
            lcResult = lcFieldName
            EXIT  && Use the first match found
        ENDIF
    ENDFOR
    
    RETURN lcResult
ENDFUNC

* Helper function to check if a record matches criteria using dynamic field names
FUNCTION RecordMatchesCriteria(lcActivoField, lcWebField)
    LOCAL llResult, lcActivoValue, lcWebValue
    llResult = .F.
    
    TRY
        IF !EMPTY(lcActivoField) AND !EMPTY(lcWebField)
            lcActivoValue = EVALUATE(lcActivoField)
            lcWebValue = EVALUATE(lcWebField)
            
            * Handle potential null/empty values safely
            IF !ISNULL(lcActivoValue) AND !ISNULL(lcWebValue)
                lcActivoValue = TRANSFORM(lcActivoValue)
                lcWebValue = TRANSFORM(lcWebValue)
                
                * Log para ver los valores actuales (primeros 5 registros)
                IF RECNO() <= 5
                    WriteLog("DEBUG RecordCriteria: Reg #" + TRANSFORM(RECNO()) + ": " + lcActivoField + "='" + lcActivoValue + "', " + lcWebField + "='" + lcWebValue + "'")
                ENDIF
                
                * Criterio original - solo aceptamos "S" como se ha verificado en el dataset
                LOCAL lcActivoUpper, lcWebUpper
                lcActivoUpper = UPPER(ALLTRIM(lcActivoValue))
                lcWebUpper = UPPER(ALLTRIM(lcWebValue))
                
                * Verificamos que ambos campos sean exactamente "S"
                llResult = (lcActivoUpper = "S" AND lcWebUpper = "S")
                
                * Log para ver cuáles registros pasan (primeros 5)
                IF RECNO() <= 5
                    WriteLog("DEBUG RecordCriteria: Reg #" + TRANSFORM(RECNO()) + " Match? " + IIF(llResult, "SI", "NO"))
                ENDIF
            ENDIF
        ENDIF
    CATCH TO loError
        * Return false on any error
        llResult = .F.
        WriteLog("ERROR RecordMatchesCriteria: " + loError.Message)
    ENDTRY
    
    RETURN llResult
ENDFUNC

* Prepara la lista de productos desde el archivo DBF
FUNCTION PrepareProducts(lcArticuloPath)
    LOCAL lnCount, lnResult, lnIndex
    
    WriteLog("PrepareProducts: ENTRADA - Verificando almacenamiento de productos")
    WriteLog("PrepareProducts: gcProductList inicial: '" + LEFT(gcProductList, 50) + "'")
    WriteLog("PrepareProducts: gnProductCount inicial: " + TRANSFORM(gnProductCount))
    
    lnCount = 0
    lnResult = 0
    
    * Inicializar las variables globales
    gcProductList = ""
    gnProductCount = 0
    
    WriteLog("PrepareProducts: Variables inicializadas")
    
    TRY
        WriteLog("- Verificando archivo DBF: " + lcArticuloPath)
        
        IF FILE(lcArticuloPath)
            WriteLog("- Archivo DBF encontrado, leyendo datos...")
            
            * === Ensure clean state before opening ===
            IF USED("Articulos")
                USE IN Articulos
            ENDIF
            * === End clean state ===
            
            USE (lcArticuloPath) IN 0 SHARED ALIAS Articulos
            SELECT Articulos
            
            * === DEBUG: Check field structure ===
            WriteLog("DEBUG PrepareProducts: DBF tiene " + TRANSFORM(FCOUNT()) + " campos y " + TRANSFORM(RECCOUNT()) + " registros")
            
            * Dynamically find field names that contain our patterns
            LOCAL lcActivoField, lcWebField
            lcActivoField = FindFieldByPattern("ACTIVO")
            lcWebField = FindFieldByPattern("WEB")
            
            WriteLog("DEBUG PrepareProducts: Found field names:")
            WriteLog("  ACTIVO-like field: '" + lcActivoField + "'")
            WriteLog("  WEB-like field: '" + lcWebField + "'")
            
            IF EMPTY(lcActivoField) OR EMPTY(lcWebField)
                WriteLog("DEBUG PrepareProducts: Missing critical fields!")
                WriteLog("DEBUG PrepareProducts: Available fields (first 15):")
                LOCAL i
                FOR i = 1 TO MIN(FCOUNT(), 15)
                    WriteLog("  " + TRANSFORM(i) + ". '" + FIELD(i) + "'")
                ENDFOR
                
                * If we can't find the fields, abort
                IF USED("Articulos")
                    USE IN Articulos
                ENDIF
                RETURN 0
            ENDIF
            
            * Test sample values if fields found
            GO TOP
            IF !EOF()
                WriteLog("DEBUG PrepareProducts: Sample values from first record:")
                WriteLog("  " + lcActivoField + " = '" + TRANSFORM(EVALUATE(lcActivoField)) + "'")
                WriteLog("  " + lcWebField + " = '" + TRANSFORM(EVALUATE(lcWebField)) + "'")
            ENDIF
            
            * Count matching records using our helper function
            WriteLog("DEBUG PrepareProducts: Counting matching records...")
            GO TOP
            lnCount = 0
            SCAN ALL
                IF RecordMatchesCriteria(lcActivoField, lcWebField)
                    lnCount = lnCount + 1
                ENDIF
            ENDSCAN
            
            WriteLog("DEBUG PrepareProducts: Found " + TRANSFORM(lnCount) + " matching records")
            
            IF lnCount > 0
                WriteLog("- Encontrados " + TRANSFORM(lnCount) + " productos activos para web")
                LOCAL lcProductCode
                lnIndex = 0
                
                * Process matching records
                GO TOP
                SCAN ALL
                    IF RecordMatchesCriteria(lcActivoField, lcWebField)
                        lnIndex = lnIndex + 1
                        lcProductCode = ALLTRIM(Articulos.CODIGO)
                        IF !EMPTY(lcProductCode)
                            * Check for duplicates before adding
                            IF ShouldAddProduct(lcProductCode, "current_record")
                                IF EMPTY(gcProductList)
                                    gcProductList = lcProductCode
                                ELSE
                                    gcProductList = gcProductList + "," + lcProductCode
                                ENDIF
                                
                                gnProductCount = gnProductCount + 1
                                
                                * Debug para los primeros 5 productos únicos
                                IF gnProductCount <= 5
                                    WriteLog("DEBUG PrepareProducts: Producto único " + TRANSFORM(gnProductCount) + ": '" + lcProductCode + "'")
                                ENDIF
                            ELSE
                                * Product was skipped due to duplication - log it
                                WriteLog("DUPLICADO saltado: " + lcProductCode)
                            ENDIF
                        ELSE
                            WriteLog("ADVERTENCIA PrepareProducts: Producto " + TRANSFORM(lnIndex) + " tiene código vacío")
                        ENDIF
                    ENDIF
                ENDSCAN
                lnResult = gnProductCount  && Use actual unique product count
                
                * Verificar que se hayan cargado productos
                IF lnResult > 0 AND !EMPTY(gcProductList)
                    WriteLog("- Lista de productos preparada exitosamente")
                    WriteLog("PrepareProducts: RESULTADOS - Registros procesados: " + TRANSFORM(lnIndex))
                    WriteLog("PrepareProducts: RESULTADOS - Productos únicos: " + TRANSFORM(gnProductCount))
                    WriteLog("PrepareProducts: RESULTADOS - Duplicados eliminados: " + TRANSFORM(lnIndex - gnProductCount))
                    WriteLog("PrepareProducts: SALIDA - Lista length: " + TRANSFORM(LEN(gcProductList)))
                    WriteLog("PrepareProducts: SALIDA - Primer producto: '" + LEFT(gcProductList, AT(",", gcProductList + ",") - 1) + "'")
                    WriteLog("PrepareProducts: SALIDA - Primeros 100 chars: '" + LEFT(gcProductList, 100) + "'")
                    
                    * Verificar estructura de la lista (contar comas)
                    LOCAL lnCommaCount
                    lnCommaCount = OCCURS(",", gcProductList)
                    WriteLog("PrepareProducts: SALIDA - Comas encontradas: " + TRANSFORM(lnCommaCount) + " (esperadas: " + TRANSFORM(gnProductCount-1) + ")")
                ELSE
                    WriteLog("ERROR: No se pudieron cargar los productos")
                    WriteLog("PrepareProducts: ERROR - lnResult: " + TRANSFORM(lnResult))
                    WriteLog("PrepareProducts: ERROR - gcProductList empty: " + TRANSFORM(EMPTY(gcProductList)))
                    lnResult = 0
                ENDIF
            ELSE
                WriteLog("ADVERTENCIA: No se encontraron productos activos para web en el DBF")
            ENDIF
            
            * === Ensure DBF is closed ===
            IF USED("Articulos")
                USE IN Articulos
            ENDIF
            * === End DBF cleanup ===
        ELSE
            ShowError("DBF no encontrado: " + lcArticuloPath)
            WriteLog("ERROR: Archivo DBF no encontrado - " + lcArticuloPath)
        ENDIF
    CATCH TO loError
        ShowError("Error al leer el archivo DBF: " + loError.Message)
        WriteLog("ERROR: Fallo al leer el DBF - " + loError.Message)
        * Asegurar que las variables están inicializadas incluso en caso de error
        gcProductList = ""
        gnProductCount = 0
        
        * === Enhanced DBF error handling ===
        HandleDbfError("PrepareProducts", loError)
        * === End enhanced error handling ===
    ENDTRY
    
    WriteLog("PrepareProducts: FINAL - gnProductCount: " + TRANSFORM(gnProductCount) + ", Lista length: " + TRANSFORM(LEN(gcProductList)) + ", Retornando: " + TRANSFORM(lnResult))
    
    RETURN lnResult
ENDFUNC

* Sube los productos en lotes usando las variables globales gcProductList y gnProductCount
PROCEDURE UploadProductBatches(lcApiBase, lcSyncId, lnBatchSize)
    LOCAL lnTotal, lnBatches, i
    LOCAL lcResult
    lcResult = .T.
    
    * Validación de las variables globales de productos
    WriteLog("DEBUG UploadProductBatches: Verificación inicial")
    WriteLog("DEBUG: gnProductCount = " + TRANSFORM(gnProductCount))
    WriteLog("DEBUG: gcProductList length = " + TRANSFORM(LEN(gcProductList)))
    WriteLog("DEBUG: gcProductList first 50 chars = '" + LEFT(gcProductList, 50) + "'")
    WriteLog("DEBUG: Commas in gcProductList = " + TRANSFORM(OCCURS(",", gcProductList)))
    
    * Verificar si tenemos productos para procesar
    IF gnProductCount <= 0 OR EMPTY(gcProductList)
        WriteLog("ADVERTENCIA UploadProductBatches: No hay productos para procesar")
        RETURN .T.  && Return success for empty data (nothing to do)
    ENDIF
    
    WriteLog("INFO: Procesando " + TRANSFORM(gnProductCount) + " productos en la lista")
    lnTotal = gnProductCount
    
    TRY
        lnBatches = CEILING(lnTotal/lnBatchSize)
        
        WriteLog("- Preparando " + TRANSFORM(lnBatches) + " lotes de " + TRANSFORM(lnBatchSize) + " productos máximo")
        
        FOR i = 1 TO lnBatches
            LOCAL lnStart, lnEnd, lnActualBatchSize
            lnStart = (i-1)*lnBatchSize+1
            lnEnd = MIN(i*lnBatchSize, lnTotal)
            lnActualBatchSize = lnEnd-lnStart+1
            
            IF lnActualBatchSize <= 0
                WriteLog("ERROR: Tamaño de lote inválido calculado: " + TRANSFORM(lnActualBatchSize))
                LOOP && Continue to next iteration
            ENDIF
            
            * Extraer productos del string global para este lote
            LOCAL lcBatchList
            lcBatchList = ExtractProductsFromRange(lnStart, lnEnd)
            
            * === DEBUG: Log batch summary ===
            WriteLog("DEBUG: Lote " + TRANSFORM(i) + " - Rango: " + TRANSFORM(lnStart) + "-" + TRANSFORM(lnEnd))
            WriteLog("DEBUG: Tamaño calculado del lote: " + TRANSFORM(lnActualBatchSize))
            WriteLog("DEBUG: Número de productos extraídos: " + TRANSFORM(OCCURS(",", lcBatchList) + IIF(EMPTY(lcBatchList), 0, 1)))
            * === END DEBUG ===
            
            IF EMPTY(lcBatchList)
                WriteLog("ADVERTENCIA: No se pudieron extraer productos para el lote " + TRANSFORM(i))
                LOOP && Continue to next iteration
            ENDIF
            
            WriteLog("- Subiendo lote " + TRANSFORM(i) + " de " + TRANSFORM(lnBatches) + " (" + TRANSFORM(lnActualBatchSize) + " productos)")
            
            TRY
                IF .NOT. UploadBatch(lcApiBase, lcSyncId, lcBatchList)
                    ShowError("Error subiendo lote " + TRANSFORM(i))
                    WriteLog("ERROR: Falló la carga del lote " + TRANSFORM(i))
                    lcResult = .F.
                    EXIT
                ELSE
                    WriteLog("- Lote " + TRANSFORM(i) + " subido correctamente")
                ENDIF
            CATCH TO loError
                ShowError("Error al procesar lote " + TRANSFORM(i) + ": " + loError.Message)
                WriteLog("ERROR: Excepción en lote " + TRANSFORM(i) + " - " + loError.Message)
                lcResult = .F.
                EXIT
            ENDTRY
            
            * Process batch upload (JSON file logging removed)
        ENDFOR
    CATCH TO loError
        ShowError("Error general al subir lotes: " + loError.Message)
        WriteLog("ERROR CRÍTICO: Error en UploadProductBatches - " + loError.Message)
        lcResult = .F.
    ENDTRY
    
    RETURN lcResult
ENDPROC

* --- Implementación de los pasos como procedimientos ---

PROCEDURE InitSync(lcApiBase)
    LOCAL loHttp, lcUrl, lcSyncId, lnStatus, lcResponse
    
    LOCAL lcResult
    lcResult = ""
    TRY
        loHttp = CREATEOBJECT("WinHttp.WinHttpRequest.5.1")
        lcUrl = lcApiBase + "/sync"
        
        WriteLog("- Conectando a " + lcUrl)
        
        loHttp.Open("GET", lcUrl, .F.)
        loHttp.SetRequestHeader("Content-Type", "application/json")
        loHttp.SetRequestHeader("Tenant", gcTenant)
        loHttp.SetRequestHeader("Api-Key", gcApiKey)
        loHttp.SetRequestHeader("User-Agent", "Pure HTTP client v2.0")
        loHttp.Send("")
        
        lnStatus = loHttp.Status
        WriteLog("- Código de respuesta: " + TRANSFORM(lnStatus))
        
        IF lnStatus = 200 OR lnStatus = 201
            lcResponse = loHttp.ResponseText
            WriteLog("- Respuesta: " + lcResponse)
            
            * Extraer el identificador del JSON (asume {"Id":"..."})
            lcSyncId = EXTRACTID(lcResponse)
            
            IF EMPTY(lcSyncId)
                WriteLog("ADVERTENCIA: ID vacío en la respuesta")
            ENDIF
            
            lcResult = lcSyncId
        ELSE
            WriteLog("ERROR: Respuesta incorrecta - Código " + TRANSFORM(lnStatus))
            WriteLog("- Respuesta: " + loHttp.ResponseText)
        ENDIF
    CATCH TO loErr
        WriteLog("ERROR InitSync: " + loErr.Message)
    ENDTRY
    
    RETURN lcResult
ENDPROC

PROCEDURE UploadBatch(lcApiBase, lcSyncId, lcBatchList)
    LOCAL loHttp, lcUrl, lcPayload, lnStatus, lcResponse
    
    LOCAL lcResult
    lcResult = .F.
    
    * Validar que lcBatchList no esté vacío
    IF EMPTY(lcBatchList)
        WriteLog("ADVERTENCIA UploadBatch: La lista de productos del lote está vacía")
        RETURN .T.  && Return success for empty batch (nothing to do)
    ENDIF
    
    TRY
        loHttp = CREATEOBJECT("WinHttp.WinHttpRequest.5.1")
        lcUrl = lcApiBase + "/sync/" + lcSyncId
        
        * Construir el JSON de productos según el modelo de la API
        lcPayload = BuildProductsJsonFromList(lcBatchList)
        
        * Validar que el JSON se construyó correctamente
        IF EMPTY(lcPayload) OR lcPayload = "[]"
            WriteLog("ADVERTENCIA: El JSON generado está vacío")
            RETURN .T.  && No hay nada que enviar pero no es un error crítico
        ENDIF
        
        * Loguear info básica pero no el JSON completo (puede ser muy grande)
        WriteLog("- Enviando batch a " + lcUrl + " (" + TRANSFORM(LEN(lcPayload)) + " bytes)")
        
        loHttp.Open("POST", lcUrl, .F.)
        loHttp.SetRequestHeader("Content-Type", "application/json")
        loHttp.SetRequestHeader("Tenant", gcTenant)
        loHttp.SetRequestHeader("Api-Key", gcApiKey)
        loHttp.SetRequestHeader("User-Agent", "Pure HTTP client v2.0")
        loHttp.Send(lcPayload)
        
        lnStatus = loHttp.Status
        WriteLog("- Código de respuesta: " + TRANSFORM(lnStatus))
        
        IF lnStatus = 200 OR lnStatus = 201
            lcResponse = loHttp.ResponseText
            WriteLog("- Respuesta: " + LEFT(lcResponse, 100) + IIF(LEN(lcResponse)>100, "...", ""))
            lcResult = .T.
        ELSE
            WriteLog("ERROR: Respuesta incorrecta - Código " + TRANSFORM(lnStatus))
            WriteLog("- Respuesta: " + loHttp.ResponseText)
        ENDIF
    CATCH TO loErr
        WriteLog("ERROR UploadBatch: " + loErr.Message)
    ENDTRY
    
    RETURN lcResult
ENDPROC

PROCEDURE RequestSync(lcApiBase, lcSyncId)
    LOCAL loHttp, lcUrl, lnStatus, lcResponse
    
    LOCAL lcResult
    lcResult = .F.
    
    TRY
        loHttp = CREATEOBJECT("WinHttp.WinHttpRequest.5.1")
        lcUrl = lcApiBase + "/sync/" + lcSyncId
        
        WriteLog("- Solicitando sincronización a " + lcUrl)
        
        loHttp.Open("PUT", lcUrl, .F.)  && Changed from POST to PUT to match API docs
        loHttp.SetRequestHeader("Content-Type", "application/json")
        loHttp.SetRequestHeader("Tenant", gcTenant)
        loHttp.SetRequestHeader("Api-Key", gcApiKey)
        loHttp.SetRequestHeader("User-Agent", "Pure HTTP client v2.0")
        loHttp.Send("")
        
        lnStatus = loHttp.Status
        WriteLog("- Código de respuesta: " + TRANSFORM(lnStatus))
        
        IF lnStatus = 200 OR lnStatus = 201 OR lnStatus = 202
            lcResponse = loHttp.ResponseText
            WriteLog("- Respuesta: " + lcResponse)
            lcResult = .T.
        ELSE
            WriteLog("ERROR: Respuesta incorrecta - Código " + TRANSFORM(lnStatus))
            WriteLog("- Respuesta: " + loHttp.ResponseText)
        ENDIF
    CATCH TO loErr
        WriteLog("ERROR RequestSync: " + loErr.Message)
    ENDTRY
    
    RETURN lcResult
ENDPROC

PROCEDURE GetSyncStatus(lcApiBase, lcSyncId)
    LOCAL loHttp, lcUrl, lnStatus, lcResponse, lcStatus
    
    LOCAL lcResult
    lcResult = "Unknown"
    lcUrl = lcApiBase + "/sync/" + lcSyncId  && Removed /status to match API docs
    
    * Hacer polling hasta que el estado sea "Completed" o "Failed"
    LOCAL lnMaxAttempts, lnCurrentAttempt, llFinished
    lnMaxAttempts = 10  && Máximo número de intentos de polling
    lnCurrentAttempt = 0
    llFinished = .F.
    
    DO WHILE .NOT. llFinished AND lnCurrentAttempt < lnMaxAttempts
        lnCurrentAttempt = lnCurrentAttempt + 1
        WriteLog("- Intento " + TRANSFORM(lnCurrentAttempt) + " de " + TRANSFORM(lnMaxAttempts))
        
        TRY
            loHttp = CREATEOBJECT("WinHttp.WinHttpRequest.5.1")
            
            WriteLog("- Consultando estado en " + lcUrl)
            
            loHttp.Open("GET", lcUrl, .F.)
            loHttp.SetRequestHeader("Content-Type", "application/json")
            loHttp.SetRequestHeader("Tenant", gcTenant)
            loHttp.SetRequestHeader("Api-Key", gcApiKey)
            loHttp.SetRequestHeader("User-Agent", "Pure HTTP client v2.0")
            loHttp.Send()
            
            lnStatus = loHttp.Status
            WriteLog("- Código de respuesta: " + TRANSFORM(lnStatus))
            
            IF lnStatus = 200
                lcResponse = loHttp.ResponseText
                WriteLog("- Respuesta: " + lcResponse)
                
                lcStatus = EXTRACTSTATUS(lcResponse)  && Extraer el estado del JSON
                WriteLog("- Estado actual: " + lcStatus)
                
                * Si el estado es terminal, terminar el polling
                IF lcStatus = "Completed" OR lcStatus = "Failed" OR lcStatus = "Error"
                    llFinished = .T.
                    lcResult = lcStatus
                ELSE
                    * Esperar antes del siguiente intento
                    WriteLog("- Esperando 3 segundos...")
                    INKEY(3)  && Esperar 3 segundos
                ENDIF
            ELSE
                WriteLog("- Error HTTP: " + TRANSFORM(lnStatus))
                WriteLog("- Respuesta: " + loHttp.ResponseText)
                INKEY(2)  && Esperar 2 segundos antes de reintentar
            ENDIF
        CATCH TO loErr
            WriteLog("ERROR GetSyncStatus: " + loErr.Message)
            INKEY(2)  && Esperar 2 segundos antes de reintentar
        ENDTRY
    ENDDO
    
    RETURN lcResult
ENDPROC

* --- Funciones de utilidad y helpers ---

* Verificar conexión a Internet
FUNCTION CheckInternetConnection
    LOCAL loHttp, llConnected
    
    llConnected = .F.
    
    TRY
        loHttp = CREATEOBJECT("WinHttp.WinHttpRequest.5.1")
        WriteLog("- Verificando conexión a Internet...")
        loHttp.Open("HEAD", "https://google.com", .F.)
        loHttp.SetRequestHeader("User-Agent", "Pure HTTP client v2.0")
        loHttp.Send()
        llConnected = (loHttp.Status = 200)
        WriteLog("- Conexión a Internet: " + IIF(llConnected, "Disponible", "No disponible"))
    CATCH TO loErr
        WriteLog("ERROR CheckInternetConnection: " + loErr.Message)
        llConnected = .F.
    ENDTRY
    
    RETURN llConnected
ENDFUNC

* Inicializar archivo de log
PROCEDURE InitLog
    LOCAL lcTimeStamp
    lcTimeStamp = TRANSFORM(DATETIME())
    
    * Crear el archivo de log o reiniciarlo si existe
    STRTOFILE("=== Log de Sincronización iniciado: " + lcTimeStamp + " ====" + CHR(13) + CHR(10), gcLogFile)
ENDPROC

* Escribir en el log con timestamp
PROCEDURE WriteLog(lcMessage)
    LOCAL lcTimeStamp, lcLogLine
    
    * Mostrar en pantalla
    ? lcMessage
    
    * Guardar en archivo
    lcTimeStamp = TRANSFORM(DATETIME())
    lcLogLine = "["+ lcTimeStamp + "] " + lcMessage + CHR(13) + CHR(10)
    STRTOFILE(lcLogLine, gcLogFile, 1)  && Append mode
ENDPROC

* Mostrar mensaje de error
PROCEDURE ShowError(lcMessage)
    MESSAGEBOX(lcMessage, 16, "Error")
ENDPROC

* Mostrar mensaje de advertencia
PROCEDURE ShowWarning(lcMessage)
    MESSAGEBOX(lcMessage, 48, "Advertencia")
ENDPROC

* Mostrar mensaje informativo
PROCEDURE ShowInfo(lcMessage)
    MESSAGEBOX(lcMessage, 64, "Información")
ENDPROC

* Helper: Extraer ID de respuesta JSON como {"Id":"GUID"}
FUNCTION EXTRACTID
PARAMETERS lcResponse

LOCAL lcResult
lcResult = ""

TRY
    * Remove any leading/trailing whitespace
    lcResponse = ALLTRIM(lcResponse)
    
    * Check if response starts with a quote
    IF LEFT(lcResponse, 1) == '"' AND RIGHT(lcResponse, 1) == '"'
        * Remove surrounding quotes if present
        lcResponse = SUBSTR(lcResponse, 2, LEN(lcResponse) - 2)
    ENDIF
    
    * Now parse the JSON string
    lcStart = '"identifierId":"'
    lnStart = AT(lcStart, lcResponse)
    
    IF lnStart > 0
        * Position after the identifierId key
        lnStart = lnStart + LEN(lcStart)
        
        * Find the closing quote after lnStart
        lcSub = SUBSTR(lcResponse, lnStart)
        lnEnd = AT('"', lcSub, 1)
        
        IF lnEnd > 1
            * Extract the GUID
            lcResult = SUBSTR(lcResponse, lnStart, lnEnd - 1)
        ELSE
            WriteLog("ADVERTENCIA EXTRACTID: No se encontró comilla de cierre para el identificador")
        ENDIF
    ELSE
        * Try alternative format: "Id":"value"
        lcStart = '"Id":"'
        lnStart = AT(lcStart, lcResponse)
        
        IF lnStart > 0
            * Position after the Id key
            lnStart = lnStart + LEN(lcStart)
            
            * Find the closing quote after lnStart
            lcSub = SUBSTR(lcResponse, lnStart)
            lnEnd = AT('"', lcSub, 1)
            
            IF lnEnd > 1
                * Extract the GUID
                lcResult = SUBSTR(lcResponse, lnStart, lnEnd - 1)
            ELSE
                WriteLog("ADVERTENCIA EXTRACTID: No se encontró comilla de cierre para el Id")
            ENDIF
        ELSE
            WriteLog("ADVERTENCIA EXTRACTID: No se encontró el patrón de Id en la respuesta")
        ENDIF
    ENDIF
CATCH TO loErr
    WriteLog("ERROR EXTRACTID: " + loErr.Message)
ENDTRY

* Return empty if invalid format or parsing fails
RETURN lcResult
ENDFUNC

* Helper: Extraer estado de respuesta JSON como {"Status":"XXX"}
FUNCTION EXTRACTSTATUS
PARAMETERS lcJsonResponse

LOCAL lcStatus
lcStatus = "Unknown"

TRY
    * Remove any leading/trailing whitespace
    lcJsonResponse = ALLTRIM(lcJsonResponse)
    
    * Check if response starts with a quote
    IF LEFT(lcJsonResponse, 1) == '"' AND RIGHT(lcJsonResponse, 1) == '"'
        * Remove surrounding quotes if present
        lcJsonResponse = SUBSTR(lcJsonResponse, 2, LEN(lcJsonResponse) - 2)
    ENDIF
    
    * Now parse the JSON string
    lcStart = '"Status":"'
    lnStart = AT(lcStart, lcJsonResponse)
    
    IF lnStart > 0
        * Position after the Status key
        lnStart = lnStart + LEN(lcStart)
        
        * Find the closing quote after lnStart
        lcSub = SUBSTR(lcJsonResponse, lnStart)
        lnEnd = AT('"', lcSub, 1)
        
        IF lnEnd > 1
            * Extract the Status value
            lcStatus = SUBSTR(lcJsonResponse, lnStart, lnEnd - 1)
        ENDIF
    ENDIF
CATCH TO loErr
    WriteLog("ERROR EXTRACTSTATUS: " + loErr.Message)
ENDTRY

RETURN lcStatus
ENDFUNC


* Save product list to disk for debugging purposes
PROCEDURE SaveDebugProductList()
    LOCAL lcDebugFile, lnHandle, lcContent
    
    IF EMPTY(gcProductList)
        RETURN
    ENDIF
    
    TRY
        lcDebugFile = gcDebugFolder + "debug_products_list.txt"
        
        * Create readable content
        lcContent = "=== DEBUG: Lista de Productos ===" + CHR(13) + CHR(10)
        lcContent = lcContent + "Total productos: " + TRANSFORM(gnProductCount) + CHR(13) + CHR(10)
        lcContent = lcContent + "Lista completa: " + CHR(13) + CHR(10)
        lcContent = lcContent + STRTRAN(gcProductList, ",", CHR(13) + CHR(10))
        
        lnHandle = FCREATE(lcDebugFile)
        IF lnHandle > 0
            FWRITE(lnHandle, lcContent)
            FCLOSE(lnHandle)
            WriteLog("DEBUG: Lista de productos guardada en " + lcDebugFile)
        ELSE
            WriteLog("ERROR DEBUG: No se pudo crear archivo de lista de productos")
        ENDIF
    CATCH TO loError
        WriteLog("ERROR DEBUG SaveProductList: " + loError.Message)
    ENDTRY
ENDPROC

* Force close all DBF files to prevent locks
PROCEDURE ForceCloseAllDbfs()
    LOCAL i, lcAlias, lnOpenAreas, lnClosedAreas
    
    lnOpenAreas = 0
    lnClosedAreas = 0
    
    TRY
        WriteLog("DEBUG: Iniciando limpieza completa de bases de datos...")
        
        * First pass: Close all work areas by number
        FOR i = 1 TO 255
            IF USED(i)
                lnOpenAreas = lnOpenAreas + 1
                TRY
                    lcAlias = ALIAS(i)
                    WriteLog("DEBUG: Cerrando área " + TRANSFORM(i) + " (Alias: " + lcAlias + ")")
                    USE IN (i)
                    lnClosedAreas = lnClosedAreas + 1
                CATCH TO loCloseError
                    WriteLog("ADVERTENCIA: Error cerrando área " + TRANSFORM(i) + ": " + loCloseError.Message)
                    * Try to force close anyway
                    TRY
                        CLOSE ALL
                    CATCH
                        * Ignore nested errors
                    ENDTRY
                ENDTRY
            ENDIF
        ENDFOR
        
        * Second pass: Close by known aliases (in case some remain)
        LOCAL ARRAY laKnownAliases[6]
        laKnownAliases[1] = "Articulos"
        laKnownAliases[2] = "ArtTemp"
        laKnownAliases[3] = "Tablas"
        laKnownAliases[4] = "TabTemp" 
        laKnownAliases[5] = "TablasLookup"
        laKnownAliases[6] = "TablasTemp"
        
        FOR i = 1 TO ALEN(laKnownAliases)
            TRY
                IF USED(laKnownAliases[i])
                    WriteLog("DEBUG: Cerrando alias restante: " + laKnownAliases[i])
                    USE IN (laKnownAliases[i])
                    lnClosedAreas = lnClosedAreas + 1
                ENDIF
            CATCH TO loAliasError
                WriteLog("ADVERTENCIA: Error cerrando alias " + laKnownAliases[i] + ": " + loAliasError.Message)
            ENDTRY
        ENDFOR
        
        * Third pass: Nuclear option - CLOSE ALL
        TRY
            IF lnOpenAreas > lnClosedAreas
                WriteLog("DEBUG: Ejecutando CLOSE ALL como medida de seguridad...")
                CLOSE ALL
            ENDIF
        CATCH TO loCloseAllError
            WriteLog("ADVERTENCIA: Error en CLOSE ALL: " + loCloseAllError.Message)
        ENDTRY
        
        * Final verification
        LOCAL lnStillOpen
        lnStillOpen = 0
        FOR i = 1 TO 255
            IF USED(i)
                lnStillOpen = lnStillOpen + 1
            ENDIF
        ENDFOR
        
        WriteLog("DEBUG: Limpieza completada - Áreas abiertas inicialmente: " + TRANSFORM(lnOpenAreas) + ;
                 ", Cerradas exitosamente: " + TRANSFORM(lnClosedAreas) + ;
                 ", Aún abiertas: " + TRANSFORM(lnStillOpen))
        
        IF lnStillOpen > 0
            WriteLog("ADVERTENCIA: Aún quedan " + TRANSFORM(lnStillOpen) + " áreas de trabajo abiertas")
            * List remaining open areas for debugging
            FOR i = 1 TO 255
                IF USED(i)
                    TRY
                        lcAlias = ALIAS(i)
                        WriteLog("- Área " + TRANSFORM(i) + " aún abierta: " + lcAlias)
                    CATCH
                        WriteLog("- Área " + TRANSFORM(i) + " aún abierta (alias desconocido)")
                    ENDTRY
                ENDIF
            ENDFOR
        ENDIF
        
    CATCH TO loError
        WriteLog("ERROR en ForceCloseAllDbfs: " + loError.Message)
        * Final emergency cleanup
        TRY
            CLOSE ALL
            WriteLog("DEBUG: CLOSE ALL de emergencia ejecutado")
        CATCH
            WriteLog("ERROR: Falló el CLOSE ALL de emergencia")
        ENDTRY
    ENDTRY
ENDPROC

* Emergency DBF cleanup - Minimal, robust function for when things go wrong
PROCEDURE EmergencyDbfCleanup()
    LOCAL i
    
    * This function uses minimal error handling to avoid nested TRY/CATCH issues
    WriteLog("EMERGENCIA: Ejecutando limpieza de emergencia de DBF...")
    
    * First try CLOSE ALL (fastest method)
    CLOSE ALL
    
    * Then manually close each area (belt and suspenders approach)
    FOR i = 1 TO 255
        IF USED(i)
            USE IN (i)
        ENDIF
    ENDFOR
    
    WriteLog("EMERGENCIA: Limpieza de emergencia completada")
ENDPROC

* Enhanced DBF error handler - Call this when DBF operations fail
PROCEDURE HandleDbfError(lcOperation, loError)
    PARAMETERS lcOperation, loError
    LOCAL lcErrorMsg
    
    IF TYPE("lcOperation") = "C"
        lcErrorMsg = "ERROR en operación DBF [" + lcOperation + "]: "
    ELSE
        lcErrorMsg = "ERROR en operación DBF desconocida: "
    ENDIF
    
    IF TYPE("loError") = "O"
        lcErrorMsg = lcErrorMsg + loError.Message
        IF loError.LineNo > 0
            lcErrorMsg = lcErrorMsg + " (Línea: " + TRANSFORM(loError.LineNo) + ")"
        ENDIF
    ELSE
        lcErrorMsg = lcErrorMsg + "Error desconocido"
    ENDIF
    
    WriteLog(lcErrorMsg)
    
    * Always try to clean up DBF files after an error
    TRY
        ForceCloseAllDbfs()
    CATCH
        * If even ForceCloseAll fails, use emergency cleanup
        EmergencyDbfCleanup()
    ENDTRY
ENDPROC

* Extrae una porción de productos de la lista global para formar un lote
* Pure string-based implementation - no arrays, better memory management
FUNCTION ExtractProductsFromRange(lnStart, lnEnd)
    LOCAL lcResult, lnCurrentPos, lnCount, lcProduct, lnCommaPos
    LOCAL lnProductIndex, lnStartPos, lnEndPos
    
    lcResult = ""
    
    * More detailed log to diagnose product list state
    WriteLog("DEBUG ExtractProductsFromRange: Estado inicial:")
    WriteLog("  - gnProductCount: " + TRANSFORM(gnProductCount))
    WriteLog("  - gcProductList empty?: " + TRANSFORM(EMPTY(gcProductList)))
    WriteLog("  - gcProductList length: " + TRANSFORM(LEN(gcProductList)))
    WriteLog("  - First 50 chars: '" + LEFT(gcProductList, 50) + "'")
    WriteLog("  - Commas in list: " + TRANSFORM(OCCURS(",", gcProductList)))
    
    IF EMPTY(gcProductList) OR gnProductCount <= 0
        WriteLog("DEBUG ExtractProductsFromRange: Lista vacía o sin productos")
        RETURN lcResult
    ENDIF
    
    IF lnStart < 1 OR lnEnd < lnStart OR lnStart > gnProductCount
        WriteLog("ERROR ExtractProductsFromRange: Rango inválido (" + TRANSFORM(lnStart) + "-" + TRANSFORM(lnEnd) + ") con total=" + TRANSFORM(gnProductCount))
        RETURN lcResult
    ENDIF
    
    WriteLog("DEBUG ExtractProductsFromRange: Extrayendo rango " + TRANSFORM(lnStart) + "-" + TRANSFORM(lnEnd) + " de " + TRANSFORM(gnProductCount) + " productos")
    
    TRY
        * Pure string manipulation - find products by position without creating arrays
        lnCurrentPos = 1
        lnProductIndex = 0
        
        * Additional debug logging right before parsing
        WriteLog("DEBUG: Empezando a procesar la cadena")
        WriteLog("  - Current position: " + TRANSFORM(lnCurrentPos))
        WriteLog("  - String length: " + TRANSFORM(LEN(gcProductList)))
        
        * Special case handling - check if there are no commas which means only one product
        IF OCCURS(",", gcProductList) = 0 AND !EMPTY(gcProductList)
            WriteLog("DEBUG: Detectada lista con un solo producto (sin comas)")
            lcProduct = ALLTRIM(gcProductList)
            lnProductIndex = 1
            
            * If this is the product we want (should be index 1), return it
            IF 1 >= lnStart AND 1 <= lnEnd AND !EMPTY(lcProduct)
                lcResult = lcProduct
                WriteLog("DEBUG: Retornando producto único: '" + lcProduct + "'")
            ENDIF
        ELSE
            * Normal case - multiple products with commas        * Walk through the comma-separated string
        DO WHILE lnCurrentPos <= LEN(gcProductList) AND lnProductIndex < lnEnd
            * Find next comma AFTER the current position
            * In VFP, AT() with 3 parameters is for occurrence number, not start position
            * We need to find commas only in the subset of the string after our current position
            LOCAL lcSubString, lnSubCommaPos
            lcSubString = SUBSTR(gcProductList, lnCurrentPos)
            lnSubCommaPos = AT(",", lcSubString)
            
            * Calculate the actual comma position in the full string
            IF lnSubCommaPos > 0
                lnCommaPos = lnCurrentPos + lnSubCommaPos - 1
            ELSE
                lnCommaPos = 0
            ENDIF
            
            * Debug for first 3 iterations
            IF lnProductIndex < 3
                WriteLog("DEBUG Iterate: Index=" + TRANSFORM(lnProductIndex) + ", Pos=" + TRANSFORM(lnCurrentPos) + ", SubPos=" + TRANSFORM(lnSubCommaPos) + ", FullCommaPos=" + TRANSFORM(lnCommaPos))
                WriteLog("  SubString: '" + LEFT(lcSubString, 20) + IIF(LEN(lcSubString) > 20, "...", "") + "'")
            ENDIF
            
            IF lnCommaPos = 0
                lnCommaPos = LEN(gcProductList) + 1  && Point to end
            ENDIF
                
                * Extract current product
                lcProduct = SUBSTR(gcProductList, lnCurrentPos, lnCommaPos - lnCurrentPos)
                lcProduct = ALLTRIM(lcProduct)
                lnProductIndex = lnProductIndex + 1
                
                * Debug info for first few products
                IF lnProductIndex <= 3 OR (lnProductIndex >= lnStart AND lnProductIndex <= lnStart + 2)
                    WriteLog("DEBUG Product: Index=" + TRANSFORM(lnProductIndex) + ", Value='" + lcProduct + "'")
                ENDIF
                
                * If this product is in our desired range, add it to result
                IF lnProductIndex >= lnStart AND lnProductIndex <= lnEnd AND !EMPTY(lcProduct)
                    IF !EMPTY(lcResult)
                        lcResult = lcResult + "," + lcProduct
                    ELSE
                        lcResult = lcProduct
                    ENDIF
                ENDIF
                
                * Move to next product
                lnCurrentPos = lnCommaPos + 1
            ENDDO
        ENDIF
        
    CATCH TO loError
        WriteLog("ERROR ExtractProductsFromRange: " + loError.Message)
        lcResult = ""
    ENDTRY
    
    WriteLog("DEBUG ExtractProductsFromRange: Resultado final: '" + LEFT(lcResult, 100) + IIF(LEN(lcResult)>100, "...", "") + "' (" + TRANSFORM(OCCURS(",", lcResult) + IIF(EMPTY(lcResult), 0, 1)) + " productos)")
    
    RETURN lcResult
ENDFUNC

* Helper function to remove a specific product code from the global list
PROCEDURE RemoveProductFromList(lcProductCode)
    LOCAL lnStartPos, lnEndPos, lcBeforeCode, lcAfterCode
    
    IF EMPTY(gcProductList) OR EMPTY(lcProductCode)
        RETURN
    ENDIF
    
    TRY
        * Find and remove the product code from the list
        lnStartPos = AT("," + lcProductCode + ",", "," + gcProductList + ",")
        IF lnStartPos = 1
            * It's the first item in the list
            lnEndPos = AT(",", gcProductList + ",")
            IF lnEndPos > LEN(gcProductList)
                * Only item in list
                gcProductList = ""
                gnProductCount = 0
            ELSE
                * Remove first item and comma
                gcProductList = SUBSTR(gcProductList, lnEndPos + 1)
                gnProductCount = gnProductCount - 1
            ENDIF
        ELSE
            * It's in the middle or end of the list
            lnStartPos = AT("," + lcProductCode, gcProductList)
            IF lnStartPos > 0
                lnEndPos = AT(",", gcProductList + ",", lnStartPos + 1)
                IF lnEndPos > LEN(gcProductList)
                    * It's the last item - remove comma and item
                    gcProductList = LEFT(gcProductList, lnStartPos - 1)
                    gnProductCount = gnProductCount - 1
                ELSE
                    * It's in the middle - remove item but keep comma structure
                    lcBeforeCode = LEFT(gcProductList, lnStartPos - 1)
                    lcAfterCode = SUBSTR(gcProductList, lnEndPos)
                    gcProductList = lcBeforeCode + lcAfterCode
                    gnProductCount = gnProductCount - 1
                ENDIF
            ENDIF
        ENDIF
        
        WriteLog("DEBUG RemoveProductFromList: Removido " + lcProductCode + ", count=" + TRANSFORM(gnProductCount))
        
    CATCH TO loError
        WriteLog("ERROR RemoveProductFromList: " + loError.Message)
    ENDTRY
ENDPROC

* Helper function to check if product code already exists and handle duplicates
* Returns .T. if we should add this product, .F. if it's a duplicate we should skip
FUNCTION ShouldAddProduct(lcProductCode, lcCurrentRecord)
    LOCAL llShouldAdd, lnExistingPos, lcExistingCode
    LOCAL llCurrentBetter
    
    * Check deduplication strategy
    IF gcDedupeStrategy = "NONE"
        RETURN .T.  && No deduplication - add everything
    ENDIF
    
    llShouldAdd = .T.  && Default: add the product
    
    * Check if this code already exists in our list
    IF !EMPTY(gcProductList)
        * Simple check: look for the exact code in the comma-separated list
        * We need to be careful about partial matches, so we check with commas
        lcCheckCode = "," + lcProductCode + ","
        lcCheckList = "," + gcProductList + ","
        
        IF AT(lcCheckCode, lcCheckList) > 0
            * Duplicate found! Apply strategy
            WriteLog("DUPLICADO encontrado: " + lcProductCode + " - Estrategia: " + gcDedupeStrategy)
            
            DO CASE
                CASE gcDedupeStrategy = "FIRST"
                    * Keep the first occurrence (skip this duplicate)
                    llShouldAdd = .F.
                    WriteLog("DUPLICADO descartado: " + lcProductCode + " (manteniendo el primero)")
                    
                CASE gcDedupeStrategy = "LAST"
                    * Replace the existing one with this one
                    * First remove the existing occurrence
                    RemoveProductFromList(lcProductCode)
                    llShouldAdd = .T.
                    WriteLog("DUPLICADO reemplazado: " + lcProductCode + " (manteniendo el último)")
                    
                CASE gcDedupeStrategy = "QUALITY"
                    * Use the advanced quality-based comparison
                    RETURN ShouldAddProductAdvanced(lcProductCode)
                    
                OTHERWISE
                    * Unknown strategy - default to FIRST
                    llShouldAdd = .F.
                    WriteLog("DUPLICADO descartado: " + lcProductCode + " (estrategia desconocida, usando FIRST)")
            ENDCASE
        ENDIF
    ENDIF
    
    RETURN llShouldAdd
ENDFUNC

* Advanced version: Compare two product records and return .T. if current is better
FUNCTION IsCurrentProductBetter(lcProductCode)
    LOCAL llCurrentBetter, lnQualityScore, lnCurrentScore
    
    * Quality scoring system - higher score = better product
    * We'll assign points for various quality indicators
    
    llCurrentBetter = .F.  && Default: current is not better
    lnCurrentScore = 0
    
    TRY
        * Score the current record based on multiple quality criteria:
        
        * 1. Description quality (0-20 points)
        IF !EMPTY(Articulos.DESCRIP)
            LOCAL lnDescLen
            lnDescLen = LEN(ALLTRIM(Articulos.DESCRIP))
            IF lnDescLen > 50
                lnCurrentScore = lnCurrentScore + 20  && Very good description
            ELSE
                IF lnDescLen > 20
                    lnCurrentScore = lnCurrentScore + 15  && Good description
                ELSE
                    IF lnDescLen > 5
                        lnCurrentScore = lnCurrentScore + 10  && Basic description
                    ELSE
                        lnCurrentScore = lnCurrentScore + 5   && Minimal description
                    ENDIF
                ENDIF
            ENDIF
        ENDIF
        
        * 2. Price validity (0-15 points)
        IF TYPE("Articulos.PRECIO1") = "N" AND Articulos.PRECIO1 > 0
            IF Articulos.PRECIO1 > 100
                lnCurrentScore = lnCurrentScore + 15  && High value product
            ELSE
                IF Articulos.PRECIO1 > 10
                    lnCurrentScore = lnCurrentScore + 10  && Medium value
                ELSE
                    lnCurrentScore = lnCurrentScore + 5   && Low value but valid
                ENDIF
            ENDIF
        ENDIF
        
        * 3. Image availability (0-10 points)
        IF !EMPTY(Articulos.IMAGEN)
            lnCurrentScore = lnCurrentScore + 10
        ENDIF
        
        * 4. Brand information (0-10 points)
        IF !EMPTY(Articulos.MARCA)
            lnCurrentScore = lnCurrentScore + 10
        ENDIF
        
        * 5. Category/Classification data (0-15 points)
        LOCAL lnCategoryScore
        lnCategoryScore = 0
        IF !EMPTY(Articulos.CATEGORIA)
            lnCategoryScore = lnCategoryScore + 5
        ENDIF
        IF !EMPTY(Articulos.RUBRO)
            lnCategoryScore = lnCategoryScore + 5
        ENDIF
        IF !EMPTY(Articulos.VIRTUAL)
            lnCategoryScore = lnCategoryScore + 5
        ENDIF
        lnCurrentScore = lnCurrentScore + lnCategoryScore
        
        * 6. Variant data - Colors (0-10 points)
        LOCAL lnColorCount, lnColorIndex, lcColorField
        lnColorCount = 0
        FOR lnColorIndex = 1 TO 9
            lcColorField = "C" + ALLTRIM(STR(lnColorIndex))
            IF TYPE("Articulos." + lcColorField) = "C" AND !EMPTY(EVALUATE("Articulos." + lcColorField))
                lnColorCount = lnColorCount + 1
            ENDIF
        ENDFOR
        IF lnColorCount > 5
            lnCurrentScore = lnCurrentScore + 10
        ELSE
            IF lnColorCount > 2
                lnCurrentScore = lnCurrentScore + 7
            ELSE
                IF lnColorCount > 0
                    lnCurrentScore = lnCurrentScore + 3
                ENDIF
            ENDIF
        ENDIF
        
        * 7. Variant data - Sizes (0-10 points)
        LOCAL lnSizeCount, lnSizeIndex, lcSizeField
        lnSizeCount = 0
        FOR lnSizeIndex = 1 TO 9
            lcSizeField = "T" + ALLTRIM(STR(lnSizeIndex))
            IF TYPE("Articulos." + lcSizeField) = "C" AND !EMPTY(EVALUATE("Articulos." + lcSizeField))
                lnSizeCount = lnSizeCount + 1
            ENDIF
        ENDFOR
        IF lnSizeCount > 5
            lnCurrentScore = lnCurrentScore + 10
        ELSE
            IF lnSizeCount > 2
                lnCurrentScore = lnCurrentScore + 7
            ELSE
                IF lnSizeCount > 0
                    lnCurrentScore = lnCurrentScore + 3
                ENDIF
            ENDIF
        ENDIF
        
        * 8. Special flags (0-10 points)
        IF Articulos.NOVEDAD = "S"
            lnCurrentScore = lnCurrentScore + 3  && New product
        ENDIF
        IF Articulos.OFERTA = "S"
            lnCurrentScore = lnCurrentScore + 3  && On sale
        ENDIF
        IF Articulos.WEB = "S"
            lnCurrentScore = lnCurrentScore + 4  && Web enabled
        ENDIF
        
        WriteLog("DEBUG IsCurrentProductBetter: " + lcProductCode + " score=" + TRANSFORM(lnCurrentScore))
        
        * For this simple implementation, we consider "better" if score > 50
        * You can adjust this threshold or implement more sophisticated comparison
        * against the existing product's score
        IF lnCurrentScore >= 50
            llCurrentBetter = .T.
            WriteLog("DEBUG: Producto " + lcProductCode + " considerado de alta calidad (score=" + TRANSFORM(lnCurrentScore) + ")")
        ELSE
            WriteLog("DEBUG: Producto " + lcProductCode + " score bajo (score=" + TRANSFORM(lnCurrentScore) + ")")
        ENDIF
        
    CATCH TO loError
        WriteLog("ERROR IsCurrentProductBetter: " + loError.Message)
        llCurrentBetter = .F.
    ENDTRY
    
    RETURN llCurrentBetter
ENDFUNC

* Enhanced deduplication with quality-based selection
* This version replaces existing products if the new one is "better"
FUNCTION ShouldAddProductAdvanced(lcProductCode)
    LOCAL llShouldAdd, lnExistingPos, lcUpdatedList
    LOCAL llCurrentBetter, lnStartPos, lnEndPos, lcBeforeCode, lcAfterCode
    
    llShouldAdd = .T.  && Default: add the product
    
    * Check if this code already exists in our list
    IF !EMPTY(gcProductList)
        lcCheckCode = "," + lcProductCode + ","
        lcCheckList = "," + gcProductList + ","
        lnExistingPos = AT(lcCheckCode, lcCheckList)
        
        IF lnExistingPos > 0
            * Duplicate found! Compare quality and potentially replace
            WriteLog("DUPLICADO encontrado: " + lcProductCode + " - Comparando calidad...")
            
            * Check if current record is better than the existing one
            llCurrentBetter = IsCurrentProductBetter(lcProductCode)
            
            IF llCurrentBetter
                * Replace the existing entry with the current one
                WriteLog("DUPLICADO reemplazado: " + lcProductCode + " (versión actual es mejor)")
                
                * Remove the old occurrence from the list
                * Find the position in the actual list (without added commas)
                lnExistingPos = AT("," + lcProductCode + ",", "," + gcProductList + ",")
                IF lnExistingPos = 1
                    * It's the first item in the list
                    lnStartPos = 1
                    lnEndPos = AT(",", gcProductList + ",")
                    IF lnEndPos > LEN(gcProductList)
                        * Only item in list
                        gcProductList = ""
                    ELSE
                        * Remove first item and comma
                        gcProductList = SUBSTR(gcProductList, lnEndPos + 1)
                    ENDIF
                ELSE
                    * It's in the middle or end of the list
                    lnStartPos = AT("," + lcProductCode, gcProductList)
                    IF lnStartPos > 0
                        lnEndPos = AT(",", gcProductList + ",", lnStartPos + 1)
                        IF lnEndPos > LEN(gcProductList)
                            * It's the last item - remove comma and item
                            gcProductList = LEFT(gcProductList, lnStartPos - 1)
                        ELSE
                            * It's in the middle - remove item but keep comma structure
                            lcBeforeCode = LEFT(gcProductList, lnStartPos - 1)
                            lcAfterCode = SUBSTR(gcProductList, lnEndPos)
                            gcProductList = lcBeforeCode + lcAfterCode
                        ENDIF
                    ENDIF
                ENDIF
                
                * Now add the new (better) version
                IF EMPTY(gcProductList)
                    gcProductList = lcProductCode
                ELSE
                    gcProductList = gcProductList + "," + lcProductCode
                ENDIF
                
                llShouldAdd = .F.  && Don't add again in the main loop
                WriteLog("DUPLICADO actualizado en lista: " + lcProductCode)
            ELSE
                * Keep the existing one, skip the current
                llShouldAdd = .F.
                WriteLog("DUPLICADO descartado: " + lcProductCode + " (versión existente es mejor)")
            ENDIF
        ENDIF
    ENDIF
    
    RETURN llShouldAdd
ENDFUNC

* Report and count currently open DBF files - Returns count of open files
FUNCTION ReportOpenDbfs()
    LOCAL i, lnOpenFiles, lcAlias, lcOpenFiles
    
    lnOpenFiles = 0
    lcOpenFiles = ""
    
    TRY
        WriteLog("DEBUG: Verificando archivos DBF abiertos...")
        
        * Check all possible work areas
        FOR i = 1 TO 255
            IF USED(i)
                lnOpenFiles = lnOpenFiles + 1
                TRY
                    lcAlias = ALIAS(i)
                    WriteLog("  - Área " + TRANSFORM(i) + ": " + lcAlias)
                    IF !EMPTY(lcOpenFiles)
                        lcOpenFiles = lcOpenFiles + ", "
                    ENDIF
                    lcOpenFiles = lcOpenFiles + lcAlias + "(" + TRANSFORM(i) + ")"
                CATCH TO loAliasError
                    WriteLog("  - Área " + TRANSFORM(i) + ": (alias desconocido)")
                    IF !EMPTY(lcOpenFiles)
                        lcOpenFiles = lcOpenFiles + ", "
                    ENDIF
                    lcOpenFiles = lcOpenFiles + "Unknown(" + TRANSFORM(i) + ")"
                ENDTRY
            ENDIF
        ENDFOR
        
        IF lnOpenFiles > 0
            WriteLog("ESTADO DBF: " + TRANSFORM(lnOpenFiles) + " archivos abiertos: " + lcOpenFiles)
        ELSE
            WriteLog("ESTADO DBF: Ningún archivo abierto")
        ENDIF
        
    CATCH TO loError
        WriteLog("ERROR en ReportOpenDbfs: " + loError.Message)
        * Return conservative estimate
        lnOpenFiles = -1  && Indicates error in counting
    ENDTRY
    
    RETURN lnOpenFiles
ENDFUNC

* ================================================================================
* BuildProductsJsonFromList - Construye JSON para una lista de códigos de productos
* ================================================================================
FUNCTION BuildProductsJsonFromList(lcProductList)
    LOCAL lcJson, lcCurrentProduct, lnProcessed
    LOCAL lnCurrentPos, lcProduct, lnCommaPos
    LOCAL lcVariants, lcColors, lcTalles, lcBrand, lcTags, lcPics
    LOCAL llIsNew, llIsSale, llIsUnavailable, llIsEnabled
    LOCAL lnI, lcField, lcValue, lcBrandDesc, lcTagDesc
    LOCAL lcMarcaValue, lcCategoriaValue, lcRubroValue, lcVirtualValue
    LOCAL lcNovedadValue, lcOfertaValue, lcProximoValue, lcActivoValue
    LOCAL lcImagenValue, lcCodigoValue, lcNameValue, lcDetailsValue, lnPrecio
    
    lcJson = "[]"
    lnProcessed = 0
    
    IF EMPTY(lcProductList)
        WriteLog("   ADVERTENCIA BuildProductsJsonFromList: Lista de productos vacía")
        RETURN lcJson
    ENDIF
    
    lcJson = "["
    
    TRY
        WriteLog("   - Construyendo JSON para productos de la lista: " + LEFT(lcProductList, 50) + "...")
        
        lnCurrentPos = 1
        
        * Log total number of commas for verification
        LOCAL lnTotalCommas
        lnTotalCommas = OCCURS(",", lcProductList)
        WriteLog("   - Número total de comas en la lista: " + TRANSFORM(lnTotalCommas) + " (esperados: " + TRANSFORM(lnTotalCommas + 1) + " productos)")
        
        * Use array approach for safer processing
        LOCAL laProducts[1], lnProductCount
        lnProductCount = ALINES(laProducts, lcProductList, .T., ",")
        
        * Log how many products we parsed
        WriteLog("   - Productos extraídos con ALINES: " + TRANSFORM(lnProductCount))
        
        * We no longer need lnCurrentPos - we're using array indices now
        * Remove all variables related to previous string parsing approach
        lnCurrentPos = 0
        
        * Loop through our product array instead
        FOR lnI = 1 TO lnProductCount
            lcProduct = ALLTRIM(laProducts[lnI])
            
            * Log progress periodically
            IF lnI % 50 = 0 OR lnI = 1 OR lnI = lnProductCount
                WriteLog("   - Procesando producto " + TRANSFORM(lnI) + "/" + TRANSFORM(lnProductCount) + "...")
            ENDIF
            
            * Using the product from our array now
            IF !EMPTY(lcProduct)
                * Log only first few products for debugging
                IF lnI <= 5
                    WriteLog("   - Procesando producto " + TRANSFORM(lnI) + "/" + TRANSFORM(lnProductCount) + ": '" + lcProduct + "'")
                ENDIF
                
                * Use local reference to avoid using old lcSubString variable
                LOCAL lcCurrentProduct
                lcCurrentProduct = lcProduct
                
                IF FILE(gcArticuloPath)
                    * Ensure clean state
                    IF USED("ArtTemp")
                        USE IN ArtTemp
                    ENDIF
                    
                    USE (gcArticuloPath) IN 0 SHARED ALIAS ArtTemp
                    SELECT ArtTemp
                    LOCATE FOR ALLTRIM(ArtTemp.CODIGO) = ALLTRIM(lcProduct)
                    
                    IF FOUND()
                        WriteLog("   - Producto encontrado en DBF: " + lcProduct)
                        * Build complete JSON with all fields
                        
                        * Extract Variants (Colors C1-C9)
                        lcColors = ""
                        LOCAL lnColorIdx
                        FOR lnColorIdx = 1 TO 9
                            lcField = "C" + TRANSFORM(lnColorIdx)
                            IF TYPE("ArtTemp." + lcField) != "U" AND !ISNULL(EVALUATE("ArtTemp." + lcField)) AND !EMPTY(EVALUATE("ArtTemp." + lcField))
                                * Convert to string safely regardless of data type
                                lcValue = ALLTRIM(TRANSFORM(EVALUATE("ArtTemp." + lcField)))
                                IF !EMPTY(lcValue) AND lcValue != "0" AND lcValue != ".F." AND lcValue != ".T."
                                    IF !EMPTY(lcColors)
                                        lcColors = lcColors + ","
                                    ENDIF
                                    lcColors = lcColors + '"' + STRTRAN(lcValue, '"', '\"') + '"'
                                ENDIF
                            ENDIF
                        ENDFOR
                        
                        * Extract Variants (Talles T1-T9)
                        lcTalles = ""
                        LOCAL lnTalleIdx
                        FOR lnTalleIdx = 1 TO 9
                            lcField = "T" + TRANSFORM(lnTalleIdx)
                            IF TYPE("ArtTemp." + lcField) != "U" AND !ISNULL(EVALUATE("ArtTemp." + lcField)) AND !EMPTY(EVALUATE("ArtTemp." + lcField))
                                * Convert to string safely regardless of data type
                                lcValue = ALLTRIM(TRANSFORM(EVALUATE("ArtTemp." + lcField)))
                                IF !EMPTY(lcValue) AND lcValue != "0" AND lcValue != ".F." AND lcValue != ".T."
                                    IF !EMPTY(lcTalles)
                                        lcTalles = lcTalles + ","
                                    ENDIF
                                    lcTalles = lcTalles + '"' + STRTRAN(lcValue, '"', '\"') + '"'
                                ENDIF
                            ENDIF
                        ENDFOR
                        
                        * Build Variants JSON
                        lcVariants = '['
                        lcVariants = lcVariants + '{"Variant":"Color","OrderedList":[' + lcColors + ']},'
                        lcVariants = lcVariants + '{"Variant":"Talle","OrderedList":[' + lcTalles + ']}'
                        lcVariants = lcVariants + ']'
                        
                        * Get Brand from MARCA field (lookup in table 14)
                        lcBrand = "null"
                        IF TYPE("ArtTemp.MARCA") != "U" AND !ISNULL(ArtTemp.MARCA) AND !EMPTY(ArtTemp.MARCA)
                            * Convert MARCA to string safely
                            lcMarcaValue = ALLTRIM(TRANSFORM(ArtTemp.MARCA))
                            lcBrandDesc = LookupTablas(14, lcMarcaValue)
                            IF !EMPTY(lcBrandDesc)
                                lcBrand = '"' + STRTRAN(lcBrandDesc, '"', '\"') + '"'
                            ENDIF
                        ENDIF
                        
                        * Build Tags from CATEGORIA (table 16), RUBRO (table 13), VIRTUAL (table 15)
                        lcTags = ""
                        IF TYPE("ArtTemp.CATEGORIA") != "U" AND !ISNULL(ArtTemp.CATEGORIA) AND !EMPTY(ArtTemp.CATEGORIA)
                            lcCategoriaValue = ALLTRIM(TRANSFORM(ArtTemp.CATEGORIA))
                            lcTagDesc = LookupTablas(16, lcCategoriaValue)
                            IF !EMPTY(lcTagDesc)
                                lcTags = lcTags + '"' + STRTRAN(lcTagDesc, '"', '\"') + '"'
                            ENDIF
                        ENDIF
                        IF TYPE("ArtTemp.RUBRO") != "U" AND !ISNULL(ArtTemp.RUBRO) AND !EMPTY(ArtTemp.RUBRO)
                            lcRubroValue = ALLTRIM(TRANSFORM(ArtTemp.RUBRO))
                            lcTagDesc = LookupTablas(13, lcRubroValue)
                            IF !EMPTY(lcTagDesc)
                                IF !EMPTY(lcTags)
                                    lcTags = lcTags + ","
                                ENDIF
                                lcTags = lcTags + '"' + STRTRAN(lcTagDesc, '"', '\"') + '"'
                            ENDIF
                        ENDIF
                        IF TYPE("ArtTemp.VIRTUAL") != "U" AND !ISNULL(ArtTemp.VIRTUAL) AND !EMPTY(ArtTemp.VIRTUAL)
                            lcVirtualValue = ALLTRIM(TRANSFORM(ArtTemp.VIRTUAL))
                            lcTagDesc = LookupTablas(15, lcVirtualValue)
                            IF !EMPTY(lcTagDesc)
                                IF !EMPTY(lcTags)
                                    lcTags = lcTags + ","
                                ENDIF
                                lcTags = lcTags + '"' + STRTRAN(lcTagDesc, '"', '\"') + '"'
                            ENDIF
                        ENDIF
                        
                        * Boolean flags - handle all data types safely
                        llIsNew = .F.
                        IF TYPE("ArtTemp.NOVEDAD") != "U" AND !ISNULL(ArtTemp.NOVEDAD) AND !EMPTY(ArtTemp.NOVEDAD)
                            lcNovedadValue = UPPER(ALLTRIM(TRANSFORM(ArtTemp.NOVEDAD)))
                            llIsNew = (lcNovedadValue = "S" OR lcNovedadValue = ".T." OR lcNovedadValue = "TRUE" OR lcNovedadValue = "1")
                        ENDIF
                        
                        llIsSale = .F.
                        IF TYPE("ArtTemp.OFERTA") != "U" AND !ISNULL(ArtTemp.OFERTA) AND !EMPTY(ArtTemp.OFERTA)
                            lcOfertaValue = UPPER(ALLTRIM(TRANSFORM(ArtTemp.OFERTA)))
                            llIsSale = (lcOfertaValue = "S" OR lcOfertaValue = ".T." OR lcOfertaValue = "TRUE" OR lcOfertaValue = "1")
                        ENDIF
                        
                        llIsUnavailable = .F.
                        IF TYPE("ArtTemp.PROXIMO") != "U" AND !ISNULL(ArtTemp.PROXIMO) AND !EMPTY(ArtTemp.PROXIMO)
                            lcProximoValue = UPPER(ALLTRIM(TRANSFORM(ArtTemp.PROXIMO)))
                            llIsUnavailable = (lcProximoValue = "S" OR lcProximoValue = ".T." OR lcProximoValue = "TRUE" OR lcProximoValue = "1")
                        ENDIF
                        
                        llIsEnabled = .T.
                        IF TYPE("ArtTemp.ACTIVO") != "U" AND !ISNULL(ArtTemp.ACTIVO) AND !EMPTY(ArtTemp.ACTIVO)
                            lcActivoValue = UPPER(ALLTRIM(TRANSFORM(ArtTemp.ACTIVO)))
                            llIsEnabled = !(lcActivoValue = "N" OR lcActivoValue = ".F." OR lcActivoValue = "FALSE" OR lcActivoValue = "0")
                        ENDIF
                        
                        * Pics from IMAGEN field - handle safely
                        lcPics = ""
                        IF TYPE("ArtTemp.IMAGEN") != "U" AND !ISNULL(ArtTemp.IMAGEN) AND !EMPTY(ArtTemp.IMAGEN)
                            lcImagenValue = ALLTRIM(TRANSFORM(ArtTemp.IMAGEN))
                            IF !EMPTY(lcImagenValue) AND lcImagenValue != "0" AND lcImagenValue != ".F."
                                lcPics = '"' + STRTRAN(lcImagenValue, '"', '\"') + '"'
                            ENDIF
                        ENDIF
                        
                        * Build complete JSON - handle all field types safely
                        lcCurrentProduct = "{"
                        
                        * Code field (ensure string)
                        lcCodigoValue = ALLTRIM(TRANSFORM(ArtTemp.CODIGO))
                        lcCurrentProduct = lcCurrentProduct + '"Code":"' + STRTRAN(lcCodigoValue, '"', '\"') + '",'
                        
                        * Name field (DESCRIP)
                        lcNameValue = ""
                        IF TYPE("ArtTemp.DESCRIP") != "U" AND !ISNULL(ArtTemp.DESCRIP)
                            lcNameValue = ALLTRIM(TRANSFORM(ArtTemp.DESCRIP))
                        ENDIF
                        lcCurrentProduct = lcCurrentProduct + '"Name":"' + STRTRAN(lcNameValue, '"', '\"') + '",'
                        
                        * Details field (DETALLE)
                        lcDetailsValue = ""
                        IF TYPE("ArtTemp.DETALLE") != "U" AND !ISNULL(ArtTemp.DETALLE) AND !EMPTY(ArtTemp.DETALLE)
                            lcDetailsValue = ALLTRIM(TRANSFORM(ArtTemp.DETALLE))
                        ENDIF
                        lcCurrentProduct = lcCurrentProduct + '"Details":"' + STRTRAN(lcDetailsValue, '"', '\"') + '",'
                        
                        * Price field (PRECIO1) - ensure numeric
                        lnPrecio = 0
                        IF TYPE("ArtTemp.PRECIO1") != "U" AND !ISNULL(ArtTemp.PRECIO1) AND !EMPTY(ArtTemp.PRECIO1)
                            IF TYPE("ArtTemp.PRECIO1") = "N"
                                lnPrecio = ArtTemp.PRECIO1
                            ELSE
                                lnPrecio = VAL(TRANSFORM(ArtTemp.PRECIO1))
                            ENDIF
                        ENDIF
                        lcCurrentProduct = lcCurrentProduct + '"Prices":[{"Price":' + TRANSFORM(ROUND(lnPrecio * gnIvaRate, 2)) + ',"SalePrice":0}],'
                        lcCurrentProduct = lcCurrentProduct + '"Variants":' + lcVariants + ','
                        lcCurrentProduct = lcCurrentProduct + '"Props":[],'
                        lcCurrentProduct = lcCurrentProduct + '"Brand":' + lcBrand + ','
                        lcCurrentProduct = lcCurrentProduct + '"Tags":[' + lcTags + '],'
                        lcCurrentProduct = lcCurrentProduct + '"IsNew":' + IIF(llIsNew, "true", "false") + ','
                        lcCurrentProduct = lcCurrentProduct + '"IsSale":' + IIF(llIsSale, "true", "false") + ','
                        lcCurrentProduct = lcCurrentProduct + '"IsBold":false,'
                        lcCurrentProduct = lcCurrentProduct + '"IsUnavailable":' + IIF(llIsUnavailable, "true", "false") + ','
                        lcCurrentProduct = lcCurrentProduct + '"IsEnabled":' + IIF(llIsEnabled, "true", "false") + ','
                        lcCurrentProduct = lcCurrentProduct + '"Pics":[' + lcPics + '],'
                        lcCurrentProduct = lcCurrentProduct + '"Attachs":[],'
                        lcCurrentProduct = lcCurrentProduct + '"Exclusions":[]'
                        lcCurrentProduct = lcCurrentProduct + "}"
                        
                        IF lnProcessed > 0
                            lcJson = lcJson + ","
                        ENDIF
                        
                        lcJson = lcJson + lcCurrentProduct
                        lnProcessed = lnProcessed + 1
                    ELSE
                        WriteLog("   - ADVERTENCIA: Producto no encontrado en DBF: " + lcProduct)
                    ENDIF
                    
                    * Ensure cleanup after each product
                    IF USED("ArtTemp")
                        USE IN ArtTemp
                    ENDIF
                ELSE
                    WriteLog("   - ERROR: Archivo DBF no encontrado: " + gcArticuloPath)
                ENDIF
            ENDIF
        NEXT
        
        WriteLog("   - JSON construido para " + TRANSFORM(lnProcessed) + " productos de la lista")
        WriteLog("   - Total productos en la lista original: " + TRANSFORM(lnProductCount)) 
        IF lnProcessed < lnProductCount
            WriteLog("   - ADVERTENCIA: " + TRANSFORM(lnProductCount - lnProcessed) + " productos no pudieron ser procesados!")
        ENDIF
        
    CATCH TO loError
        WriteLog("   ERROR en BuildProductsJsonFromList: " + loError.Message)
        lcJson = "[]"
    ENDTRY
    
    lcJson = lcJson + "]"
    
    RETURN lcJson
ENDFUNC

* ================================================================================
* LookupTablas - Busca descripción en TABLAS.DBF por tabla y código
* ================================================================================
FUNCTION LookupTablas(lnTabla, lcCodigo)
    LOCAL lcResult, lcTablasPath, lcCodigoStr
    
    lcResult = ""
    lcTablasPath = ADDBS(JUSTPATH(gcArticuloPath)) + "TABLAS.DBF"
    
    IF EMPTY(lcCodigo) OR EMPTY(lnTabla)
        RETURN lcResult
    ENDIF
    
    * Ensure lcCodigo is a string regardless of input type
    lcCodigoStr = ALLTRIM(TRANSFORM(lcCodigo))
    
    TRY
        IF FILE(lcTablasPath)
            * Ensure clean state
            IF USED("TablasTemp")
                USE IN TablasTemp
            ENDIF
            
            USE (lcTablasPath) IN 0 SHARED ALIAS TablasTemp
            SELECT TablasTemp
            LOCATE FOR TablasTemp.TABLA = lnTabla AND ALLTRIM(TRANSFORM(TablasTemp.CODIGO)) = lcCodigoStr
            
            IF FOUND()
                IF TYPE("TablasTemp.DESCRIP") != "U" AND !ISNULL(TablasTemp.DESCRIP)
                    lcResult = ALLTRIM(TRANSFORM(TablasTemp.DESCRIP))
                ENDIF
            ENDIF
            
            * Cleanup
            IF USED("TablasTemp")
                USE IN TablasTemp
            ENDIF
        ENDIF
        
    CATCH TO loError
        WriteLog("   ERROR en LookupTablas(" + TRANSFORM(lnTabla) + ", " + lcCodigoStr + "): " + loError.Message)
        * Ensure cleanup on error
        IF USED("TablasTemp")
            USE IN TablasTemp
        ENDIF
    ENDTRY
    
    RETURN lcResult
ENDFUNC