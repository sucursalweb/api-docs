* Visual FoxPro 9 Project: Sync ARTICULO.DBF with SucursalWeb API v2
* Reads products from configurable DBF path (default: /data/ARTICULO.DBF)
* Follows 4 main sync steps, batching 200 products in Step #2

* Configuration
#DEFINE TU_TENANT "mi-tenant-id"        && Reemplaza con tu Tenant real
#DEFINE TU_API_KEY "mi-api-key-secreto" && Reemplaza con tu Api-Key real
#DEFINE LOG_FILE "/samples/dbf-vfox/synclog.txt"  && Archivo de log

* Punto de entrada principal del programa
PROCEDURE Main
    LOCAL lcArticuloPath, lcTablasPath, lcApiBase, lnBatchSize, lnIVA
    LOCAL llLogEnabled

    lcArticuloPath = "/samples/dbf-vfox/data/ARTICULO.DBF"  && Path to ARTICULO.DBF
    lcTablasPath = "/samples/dbf-vfox/data/TABLAS.DBF"      && Path to TABLAS.DBF
    lcApiBase = "https://sucursalweb.example.com/api/v2"     && Replace with actual API base
    lnBatchSize = 200
    lnIVA = 1.21  && Multiplicador de IVA (por defecto 21%)
    llLogEnabled = .T.  && Habilitar log
    
    * Inicializar log
    IF llLogEnabled
        InitLog()
    ENDIF
    
    * Mostrar información inicial
    CLEAR
    WriteLog("=== Sincronización de Productos con SucursalWeb API v2 ===")
    WriteLog("DBF Origen: " + lcArticuloPath)
    WriteLog("Tamaño de lote: " + TRANSFORM(lnBatchSize))
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
        LOCAL lcSyncId
        lcSyncId = InitSync(lcApiBase)
        IF EMPTY(lcSyncId)
            ShowError("No se pudo inicializar la sincronización.")
            WriteLog("ERROR: No se pudo obtener un ID de sincronización")
            RETURN
        ENDIF
        WriteLog("- ID de Sincronización obtenido: " + lcSyncId)
        WriteLog("")

        * Paso 2: Leer productos del DBF y subir en lotes
        WriteLog("Paso 2: Preparando productos para sincronización...")
        LOCAL ARRAY aProducts[1]
        LOCAL lnCount
        lnCount = PrepareProducts(lcArticuloPath, @aProducts)
        IF lnCount <= 0
            ShowError("No se encontraron productos para sincronizar.")
            WriteLog("ERROR: No se encontraron productos para sincronizar o hubo un error con el archivo DBF")
            RETURN
        ENDIF
        WriteLog("- " + TRANSFORM(lnCount) + " productos preparados.")
        WriteLog("")

        WriteLog("Subiendo productos en lotes...")
        IF .NOT. UploadProductBatches(lcApiBase, lcSyncId, @aProducts, lnBatchSize)
            ShowError("Error al cargar los lotes de productos.")
            WriteLog("ERROR: Falló la carga de lotes de productos")
            RETURN
        ENDIF
        WriteLog("")

        * Paso 3: Solicitar la sincronización
        WriteLog("Paso 3: Solicitando sincronización al servidor...")
        IF .NOT. RequestSync(lcApiBase, lcSyncId)
            ShowError("No se pudo solicitar la sincronización.")
            WriteLog("ERROR: Falló la solicitud de sincronización")
            RETURN
        ENDIF
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
    
    CATCH TO loError
        * Manejo de errores general
        ShowError("Error inesperado: " + loError.Message)
        WriteLog("ERROR CRÍTICO: " + loError.Message)
        WriteLog("Línea: " + TRANSFORM(loError.LineNo))
        WriteLog("Detalles: " + loError.Details)
    ENDTRY
ENDPROC

* Prepara la lista de productos desde el archivo DBF
PROCEDURE PrepareProducts(lcArticuloPath, aProducts)
    LOCAL lnCount
    lnCount = 0
    
    TRY
        IF FILE(lcArticuloPath)
            USE (lcArticuloPath) IN 0 SHARED ALIAS Articulos
            SELECT Articulos
            COUNT FOR Articulos.ACTIVO = "S" AND Articulos.WEB = "S" TO lnCount
            
            IF lnCount > 0
                DIMENSION aProducts[lnCount]
                lnCount = 0
                SCAN ALL FOR Articulos.ACTIVO = "S" AND Articulos.WEB = "S"
                    lnCount = lnCount + 1
                    aProducts[lnCount] = Articulos.CODIGO
                ENDSCAN
            ENDIF
            USE IN Articulos
        ELSE
            ShowError("DBF no encontrado: " + lcArticuloPath)
            WriteLog("ERROR: Archivo DBF no encontrado - " + lcArticuloPath)
            RETURN 0
        ENDIF
    CATCH TO loError
        ShowError("Error al leer el archivo DBF: " + loError.Message)
        WriteLog("ERROR: Fallo al leer el DBF - " + loError.Message)
        lnCount = 0
    ENDTRY
    
    RETURN lnCount
ENDPROC

* Sube los productos en lotes
PROCEDURE UploadProductBatches(lcApiBase, lcSyncId, aProducts, lnBatchSize)
    LOCAL lnTotal, lnBatches, i, lnStart, lnEnd, llSuccess
    
    llSuccess = .T.
    lnTotal = ALEN(aProducts,1)
    lnBatches = CEILING(lnTotal/lnBatchSize)
    
    FOR i = 1 TO lnBatches
        lnStart = (i-1)*lnBatchSize+1
        lnEnd = MIN(i*lnBatchSize, lnTotal)
        LOCAL ARRAY aBatch[1]
        DIMENSION aBatch[lnEnd-lnStart+1]
        ACOPY(aProducts, aBatch, lnStart, lnEnd-lnStart+1)
        
        WriteLog("- Subiendo lote " + TRANSFORM(i) + " de " + TRANSFORM(lnBatches) + " (" + TRANSFORM(lnEnd-lnStart+1) + " productos)")
        
        TRY
            IF .NOT. UploadBatch(lcApiBase, lcSyncId, aBatch)
                ShowError("Error subiendo lote " + TRANSFORM(i))
                WriteLog("ERROR: Falló la carga del lote " + TRANSFORM(i))
                llSuccess = .F.
                EXIT
            ENDIF
        CATCH TO loError
            ShowError("Error al procesar lote " + TRANSFORM(i) + ": " + loError.Message)
            WriteLog("ERROR: Excepción en lote " + TRANSFORM(i) + " - " + loError.Message)
            llSuccess = .F.
            EXIT
        ENDTRY
    ENDFOR
    
    RETURN llSuccess
ENDPROC

* --- Implementación de los pasos como procedimientos ---

PROCEDURE InitSync(lcApiBase)
    LOCAL loHttp, lcUrl, lcSyncId, lnStatus, lcResponse
    
    TRY
        loHttp = CREATEOBJECT("WinHttp.WinHttpRequest.5.1")
        lcUrl = lcApiBase + "/sync"
        
        WriteLog("- Conectando a " + lcUrl)
        
        loHttp.Open("POST", lcUrl, .F.)
        loHttp.SetRequestHeader("Content-Type", "application/json")
        loHttp.SetRequestHeader("Tenant", TU_TENANT)
        loHttp.SetRequestHeader("Api-Key", TU_API_KEY)
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
            
            RETURN lcSyncId
        ELSE
            WriteLog("ERROR: Respuesta incorrecta - Código " + TRANSFORM(lnStatus))
            WriteLog("- Respuesta: " + loHttp.ResponseText)
        ENDIF
    CATCH TO loErr
        WriteLog("ERROR InitSync: " + loErr.Message)
    ENDTRY
    
    RETURN ""
ENDPROC

PROCEDURE UploadBatch(lcApiBase, lcSyncId, aBatch)
    LOCAL loHttp, lcUrl, lcPayload, lnStatus, lcResponse
    
    TRY
        loHttp = CREATEOBJECT("WinHttp.WinHttpRequest.5.1")
        lcUrl = lcApiBase + "/sync/" + lcSyncId
        
        * Construir el JSON de productos según el modelo de la API
        lcPayload = BuildProductsJson(aBatch)
        
        * Loguear info básica pero no el JSON completo (puede ser muy grande)
        WriteLog("- Enviando batch a " + lcUrl + " (" + TRANSFORM(LEN(lcPayload)) + " bytes)")
        
        loHttp.Open("POST", lcUrl, .F.)
        loHttp.SetRequestHeader("Content-Type", "application/json")
        loHttp.SetRequestHeader("Tenant", TU_TENANT)
        loHttp.SetRequestHeader("Api-Key", TU_API_KEY)
        loHttp.SetRequestHeader("User-Agent", "Pure HTTP client v2.0")
        loHttp.Send(lcPayload)
        
        lnStatus = loHttp.Status
        WriteLog("- Código de respuesta: " + TRANSFORM(lnStatus))
        
        IF lnStatus = 200 OR lnStatus = 201
            lcResponse = loHttp.ResponseText
            WriteLog("- Respuesta: " + LEFT(lcResponse, 100) + IIF(LEN(lcResponse)>100, "...", ""))
            RETURN .T.
        ELSE
            WriteLog("ERROR: Respuesta incorrecta - Código " + TRANSFORM(lnStatus))
            WriteLog("- Respuesta: " + loHttp.ResponseText)
        ENDIF
    CATCH TO loErr
        WriteLog("ERROR UploadBatch: " + loErr.Message)
    ENDTRY
    
    RETURN .F.
ENDPROC

PROCEDURE RequestSync(lcApiBase, lcSyncId)
    LOCAL loHttp, lcUrl, lnStatus, lcResponse
    
    TRY
        loHttp = CREATEOBJECT("WinHttp.WinHttpRequest.5.1")
        lcUrl = lcApiBase + "/sync/" + lcSyncId + "/process"
        
        WriteLog("- Solicitando sincronización a " + lcUrl)
        
        loHttp.Open("POST", lcUrl, .F.)
        loHttp.SetRequestHeader("Content-Type", "application/json")
        loHttp.SetRequestHeader("Tenant", TU_TENANT)
        loHttp.SetRequestHeader("Api-Key", TU_API_KEY)
        loHttp.SetRequestHeader("User-Agent", "Pure HTTP client v2.0")
        loHttp.Send("")
        
        lnStatus = loHttp.Status
        WriteLog("- Código de respuesta: " + TRANSFORM(lnStatus))
        
        IF lnStatus = 200 OR lnStatus = 201 OR lnStatus = 202
            lcResponse = loHttp.ResponseText
            WriteLog("- Respuesta: " + lcResponse)
            RETURN .T.
        ELSE
            WriteLog("ERROR: Respuesta incorrecta - Código " + TRANSFORM(lnStatus))
            WriteLog("- Respuesta: " + loHttp.ResponseText)
        ENDIF
    CATCH TO loErr
        WriteLog("ERROR RequestSync: " + loErr.Message)
    ENDTRY
    
    RETURN .F.
ENDPROC

PROCEDURE GetSyncStatus(lcApiBase, lcSyncId)
    LOCAL loHttp, lcUrl, lnStatus, lcResponse, lcStatus
    
    loHttp = CREATEOBJECT("WinHttp.WinHttpRequest.5.1")
    lcUrl = lcApiBase + "/sync/" + lcSyncId + "/status"
    lcStatus = "Unknown"
    
    * Hacer polling hasta que el estado sea "Completed" o "Failed"
    LOCAL lnMaxAttempts, lnCurrentAttempt, llFinished
    lnMaxAttempts = 10  && Máximo número de intentos de polling
    lnCurrentAttempt = 0
    llFinished = .F.
    
    DO WHILE .NOT. llFinished AND lnCurrentAttempt < lnMaxAttempts
        lnCurrentAttempt = lnCurrentAttempt + 1
        WriteLog("- Intento " + TRANSFORM(lnCurrentAttempt) + " de " + TRANSFORM(lnMaxAttempts))
        
        TRY
            loHttp.Open("GET", lcUrl, .F.)
            loHttp.SetRequestHeader("Tenant", TU_TENANT)
            loHttp.SetRequestHeader("Api-Key", TU_API_KEY)
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
                ELSE
                    * Esperar antes del siguiente intento
                    WriteLog("- Esperando 3 segundos...")
                    SLEEP(3000)  && Esperar 3 segundos
                ENDIF
            ELSE
                WriteLog("- Error HTTP: " + TRANSFORM(lnStatus))
                WriteLog("- Respuesta: " + loHttp.ResponseText)
                SLEEP(2000)  && Esperar 2 segundos antes de reintentar
            ENDIF
        CATCH TO loErr
            WriteLog("- Error GetSyncStatus: " + loErr.Message)
            SLEEP(2000)  && Esperar 2 segundos antes de reintentar
        ENDTRY
    ENDDO
    
    RETURN lcStatus
ENDPROC

* --- Funciones de utilidad y helpers ---

* Verificar conexión a Internet
FUNCTION CheckInternetConnection
    LOCAL loHttp, llConnected
    
    llConnected = .F.
    
    TRY
        loHttp = CREATEOBJECT("WinHttp.WinHttpRequest.5.1")
        loHttp.Open("HEAD", "https://google.com", .F.)
        loHttp.Send()
        llConnected = (loHttp.Status = 200)
    CATCH
        llConnected = .F.
    ENDTRY
    
    RETURN llConnected
ENDFUNC

* Inicializar archivo de log
PROCEDURE InitLog
    LOCAL lcTimeStamp
    lcTimeStamp = TRANSFORM(DATETIME())
    
    * Crear el archivo de log o reiniciarlo si existe
    STRTOFILE("=== Log de Sincronización iniciado: " + lcTimeStamp + " ====" + CHR(13) + CHR(10), LOG_FILE)
ENDPROC

* Escribir en el log con timestamp
PROCEDURE WriteLog(lcMessage)
    LOCAL lcTimeStamp, lcLogLine
    
    * Mostrar en pantalla
    ? lcMessage
    
    * Guardar en archivo
    lcTimeStamp = TRANSFORM(DATETIME())
    lcLogLine = "["+ lcTimeStamp + "] " + lcMessage + CHR(13) + CHR(10)
    STRTOFILE(lcLogLine, LOG_FILE, 1)  && Append mode
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
PROCEDURE EXTRACTID(lcJsonResponse)
    LOCAL lcId
    lcId = ""
    
    * Implementación básica para extraer ID (mejora según formato real)
    * Este método simple asume formato exacto {"Id":"XXXX"}
    IF '"Id":"' $ lcJsonResponse
        lcId = SUBSTR(lcJsonResponse, AT('"Id":"', lcJsonResponse) + 6)
        lcId = LEFT(lcId, AT('"', lcId) - 1)
    ENDIF
    
    RETURN lcId
ENDPROC

* Helper: Extraer estado de respuesta JSON como {"Status":"XXX"}
PROCEDURE EXTRACTSTATUS(lcJsonResponse)
    LOCAL lcStatus
    lcStatus = "Unknown"
    
    * Implementación básica para extraer Status (mejora según formato real)
    IF '"Status":"' $ lcJsonResponse
        lcStatus = SUBSTR(lcJsonResponse, AT('"Status":"', lcJsonResponse) + 10)
        lcStatus = LEFT(lcStatus, AT('"', lcStatus) - 1)
    ENDIF
    
    RETURN lcStatus
ENDPROC

* Construir JSON para los productos
PROCEDURE BuildProductsJson(aBatch)
    LOCAL lcJson, i, lcArticuloPath, lcDbfPath, lcCurrentProduct
    lcArticuloPath = "/samples/dbf-vfox/data/ARTICULO.DBF"  && Path to ARTICULO.DBF
    lcTablasPath = "/samples/dbf-vfox/data/TABLAS.DBF"      && Path to TABLAS.DBF
    
    * Iniciar el array JSON
    lcJson = "["
    
    TRY
        FOR i = 1 TO ALEN(aBatch)
            LOCAL lcCodigo
            lcCodigo = aBatch[i]
            
            IF FILE(lcArticuloPath)
                * Abre el DBF y busca el producto actual
                USE (lcArticuloPath) IN 0 SHARED ALIAS ArtTemp
                SELECT ArtTemp
                LOCATE FOR ArtTemp.CODIGO = lcCodigo
                
                IF FOUND()
                    * Construir objeto JSON del producto
                    lcCurrentProduct = "{"

                    * Code
                    lcCurrentProduct = lcCurrentProduct + ["] + "Code" + [":""] + ALLTRIM(ArtTemp.CODIGO) + [","]
                    * Name
                    lcCurrentProduct = lcCurrentProduct + ["] + "Name" + [":""] + ALLTRIM(STRTRAN(ArtTemp.DESCRIP, '"', '\"')) + [","]
                    * Details
                    lcCurrentProduct = lcCurrentProduct + ["] + "Details" + [":""] + IIF(EMPTY(ArtTemp.DETALLE), "", ALLTRIM(STRTRAN(ArtTemp.DETALLE, '"', '\"'))) + [","]
                    * Prices
                    lcCurrentProduct = lcCurrentProduct + ["] + "Prices" + [":[{"] + "Price" + [":] + TRANSFORM(ROUND(ArtTemp.PRECIO1 * lnIVA, 2)) + [,"] + "SalePrice" + [":0}],"]
                    * Variants
                    lcCurrentProduct = lcCurrentProduct + ["] + "Variants" + [":[{"] + "Variant" + [":""] + "Color" + [\"","] + "OrderedList" + [":[]
                    FOR i = 1 TO 9
                        lcColorField = "C" + ALLTRIM(STR(i))
                        IF TYPE("ArtTemp." + lcColorField) = "C" AND !EMPTY(EVALUATE("ArtTemp." + lcColorField))
                            IF i > 1
                                lcCurrentProduct = lcCurrentProduct + ","
                            ENDIF
                            lcCurrentProduct = lcCurrentProduct + ["] + ALLTRIM(EVALUATE("ArtTemp." + lcColorField)) + [\"]
                        ENDIF
                    ENDFOR
                    lcCurrentProduct = lcCurrentProduct + "]},"
                    * Talle
                    lcCurrentProduct = lcCurrentProduct + "{"] + "Variant" + [":""] + "Talle" + [\"","] + "OrderedList" + [":[]
                    FOR i = 1 TO 9
                        lcTalleField = "T" + ALLTRIM(STR(i))
                        IF TYPE("ArtTemp." + lcTalleField) = "C" AND !EMPTY(EVALUATE("ArtTemp." + lcTalleField))
                            IF i > 1
                                lcCurrentProduct = lcCurrentProduct + ","
                            ENDIF
                            lcCurrentProduct = lcCurrentProduct + ["] + ALLTRIM(EVALUATE("ArtTemp." + lcTalleField)) + [\"]
                        ENDIF
                    ENDFOR
                    lcCurrentProduct = lcCurrentProduct + "]}],"

                    * Brand
                    lcCurrentProduct = lcCurrentProduct + ["] + "Brand" + [":] + IIF(EMPTY(ArtTemp.MARCA), "null", ["] + GetBrand(ArtTemp.MARCA, lcTablasPath) + [\""]) + [,]

                    * Tags (example: Rubro, Categoria, etc.)
                    lcCurrentProduct = lcCurrentProduct + ["] + "Tags" + [":[]
                    IF !EMPTY(ArtTemp.CATEGORIA)
                        lcCurrentProduct = lcCurrentProduct + ["] + GetClassification(ArtTemp.CATEGORIA,, lcTablasPath) + [\"]
                    ENDIF
                    IF !EMPTY(ArtTemp.RUBRO)
                        lcCurrentProduct = lcCurrentProduct + ["] + GetCategory(ArtTemp.RUBRO,, lcTablasPath) + [\"]
                    ENDIF
                    IF !EMPTY(ArtTemp.VIRTUAL)
                        lcCurrentProduct = lcCurrentProduct + ["] + GetTag(ArtTemp.VIRTUAL,, lcTablasPath) + [\"]
                    ENDIF
                    lcCurrentProduct = lcCurrentProduct + "],"

                    * IsNew, IsSale, IsBold, IsUnavailable, IsEnabled
                    lcCurrentProduct = lcCurrentProduct + ["] + "IsNew" + [":] + IIF(ArtTemp.NOVEDAD = \"S\", .T., .F.) + [,]
                    lcCurrentProduct = lcCurrentProduct + ["] + "IsSale" + [":] + IIF(ArtTemp.OFERTA = \"S\", .T., .F.) + [,]
                    lcCurrentProduct = lcCurrentProduct + ["] + "IsUnavailable" + [":] + IIF(ArtTemp.PROXIMO = \"S\", .T., .F.) + [,]
                    lcCurrentProduct = lcCurrentProduct + ["] + "IsEnabled" + [":] + IIF(ArtTemp.WEB = \"S\", .T., .F.) + [,]

                    * Pics
                    lcCurrentProduct = lcCurrentProduct + ["] + "Pics" + [":[]
                    IF !EMPTY(ArtTemp.IMAGEN)
                        lcCurrentProduct = lcCurrentProduct + ["] + ALLTRIM(ArtTemp.IMAGEN) + [\"]
                    ENDIF
                    lcCurrentProduct = lcCurrentProduct + "],"

                    * Attachs
                    lcCurrentProduct = lcCurrentProduct + ["] + "Attachs" + [":[]"

                    * Close object
                    lcCurrentProduct = lcCurrentProduct + "}"
                    
                    * Agregar al JSON principal con coma si no es el último
                    IF i < ALEN(aBatch)
                        lcCurrentProduct = lcCurrentProduct + ","
                    ENDIF
                    lcJson = lcJson + lcCurrentProduct
                ENDIF
                USE IN ArtTemp
            ENDIF
        ENDFOR
    CATCH TO loError
        WriteLog("ERROR en BuildProductsJson: " + loError.Message)
    ENDTRY
    
    lcJson = lcJson + "]"
    RETURN lcJson
ENDPROC

* Obtener nombre de categoría desde TABLAS
FUNCTION GetCategory(lnCategoryId, lcTablasPath)
    LOCAL lcName
    lcName = ""
    
    IF FILE(lcTablasPath)
        USE (lcTablasPath) IN 0 SHARED ALIAS TablasTemp
        SELECT TablasTemp
        LOCATE FOR TablasTemp.TABLA = 13 AND TablasTemp.CODIGO = lnCategoryId
        IF FOUND()
            lcName = ALLTRIM(TablasTemp.DESCRIP)
        ENDIF
        USE IN TablasTemp
    ENDIF
    
    RETURN lcName
ENDFUNC

* Obtener nombre de marca desde TABLAS
FUNCTION GetBrand(lnBrandId, lcTablasPath)
    LOCAL lcName
    lcName = ""
    
    IF FILE(lcTablasPath)
        USE (lcTablasPath) IN 0 SHARED ALIAS TablasTemp
        SELECT TablasTemp
        LOCATE FOR TablasTemp.TABLA = 14 AND TablasTemp.CODIGO = lnBrandId
        IF FOUND()
            lcName = ALLTRIM(TablasTemp.DESCRIP)
        ENDIF
        USE IN TablasTemp
    ENDIF
    
    RETURN lcName
ENDFUNC

* Obtener array JSON de tags/etiquetas
FUNCTION GetTag(lnTagId, lcTablasPath)
    LOCAL lcTags
    lcTags = ""
    
    IF FILE(lcTablasPath) AND lnTagId > 0
        USE (lcTablasPath) IN 0 SHARED ALIAS TablasTemp
        SELECT TablasTemp
        LOCATE FOR TablasTemp.TABLA = 15 AND TablasTemp.CODIGO = lnTagId
        IF FOUND()
            lcTags = ["] + ALLTRIM(TablasTemp.DESCRIP) + ["]
        ENDIF
        USE IN TablasTemp
    ENDIF
    
    RETURN lcTags
ENDFUNC

* Obtener array JSON de clasificaciones
FUNCTION GetClassification(lnClassId, lcTablasPath)
    LOCAL lcClass
    lcClass = ""
    
    IF FILE(lcTablasPath) AND lnClassId > 0
        USE (lcTablasPath) IN 0 SHARED ALIAS TablasTemp
        SELECT TablasTemp
        LOCATE FOR TablasTemp.TABLA = 16 AND TablasTemp.CODIGO = lnClassId
        IF FOUND()
            lcClass = ["] + ALLTRIM(TablasTemp.DESCRIP) + ["]
        ENDIF
        USE IN TablasTemp
    ENDIF
    
    RETURN lcClass
ENDFUNC

* Construir array JSON de variantes (talles y colores)
FUNCTION BuildVariantsArray(toProduct)
    LOCAL lcVariants, i, j, lcTalle, lcColor, llHasVariant
    
    lcVariants = ""
    llHasVariant = .F.
    
    * Verificar si hay talles (T1-T9) o colores (C1-C9)
    FOR i = 1 TO 9
        lcTalleField = "T" + ALLTRIM(STR(i))
        IF TYPE("toProduct." + lcTalleField) = "C" AND !EMPTY(EVALUATE("toProduct." + lcTalleField))
            lcTalle = ALLTRIM(EVALUATE("toProduct." + lcTalleField))
            
            FOR j = 1 TO 9
                lcColorField = "C" + ALLTRIM(STR(j))
                IF TYPE("toProduct." + lcColorField) = "C" AND !EMPTY(EVALUATE("toProduct." + lcColorField))
                    lcColor = ALLTRIM(EVALUATE("toProduct." + lcColorField))
                    
                    * Agregar coma si ya hay una variante anterior
                    IF llHasVariant
                        lcVariants = lcVariants + ","
                    ENDIF
                    
                    * Agregar la variante de talle+color
                    lcVariants = lcVariants + "{"
                    lcVariants = lcVariants + ["] + "Size" + [":""] + lcTalle + [","]
                    lcVariants = lcVariants + ["] + "Color" + [":""] + lcColor + [""]
                    lcVariants = lcVariants + "}"
                    
                    llHasVariant = .T.
                ENDIF
            ENDFOR
        ENDIF
    ENDFOR
    
    * Si no hay variantes, incluir al menos una vacía
    IF !llHasVariant
        lcVariants = lcVariants + "{"
        lcVariants = lcVariants + ["] + "Size" + [":"","]
        lcVariants = lcVariants + ["] + "Color" + [":""]
        lcVariants = lcVariants + "}"
    ENDIF
    
    RETURN lcVariants
ENDFUNC

* Helper: SyncBatchWithAPI (using WinHttp.WinHttpRequest.5.1)
PROCEDURE SyncBatchWithAPI(aBatch, lcApiBase)
    LOCAL loHttp, lcUrl, lcPayload, lcResponse, lnStatus
    loHttp = CREATEOBJECT("WinHttp.WinHttpRequest.5.1")
    lcUrl = lcApiBase + "/products/sync"  && Adjust endpoint as needed
    
    * Prepare JSON payload (simple array of codes for example)
    lcPayload = "[" + CHR(34) + JOIN(aBatch, CHR(34)+","+CHR(34)) + CHR(34) + "]"
    
    TRY
        loHttp.Open("POST", lcUrl, .F.)
        loHttp.SetRequestHeader("Content-Type", "application/json")
        * Autenticación según las reglas: Tenant y Api-Key
        loHttp.SetRequestHeader("Tenant", TU_TENANT)
        loHttp.SetRequestHeader("Api-Key", TU_API_KEY)
        loHttp.SetRequestHeader("User-Agent", "Pure HTTP client v1.0")  && Opcional, recomendado
        loHttp.Send(lcPayload)
        lnStatus = loHttp.Status
        lcResponse = loHttp.ResponseText
        IF lnStatus = 200 OR lnStatus = 201
            * Success
            WriteLog("Batch synced successfully.")
        ELSE
            WriteLog("API Error: " + TRANSFORM(lnStatus) + ", Response: " + lcResponse)
        ENDIF
    CATCH TO loErr
        WriteLog("HTTP Error: " + loErr.Message)
    ENDTRY
ENDPROC

* Ejecutar el programa
DO Main
