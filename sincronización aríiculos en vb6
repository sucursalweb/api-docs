Private Sub cmdSincronizar_Click()
Dim msg        As String
Dim sql        As String
Dim idAux      As Single
Dim colVar     As Object
Dim lidAux     As Single
Dim lcolVar    As Object
Dim valorReg   As String
Dim cantReg    As Long
Dim lcantReg   As Long
Dim i          As Integer
Dim x          As Integer
Dim req        As Object
Dim identificador As String
Dim strArt     As String
Dim articulo   As String
Dim vvalor(1)  As String
Dim strVar     As String
Dim strTenant  As String
Dim strKey     As String
Dim strHttp    As String
Dim pos        As Single

On Error GoTo ferror

sql = "SELECT valorpar FROM parametros WHERE parametrospar='webTenant'"
Call clsDb.buscar_entabla("general", sql, False, vvalor)
strTenant = Trim(vvalor(0))
sql = "SELECT valorpar FROM parametros WHERE parametrospar='webKey'"
Call clsDb.buscar_entabla("general", sql, False, vvalor)
strKey = Trim(vvalor(0))
sql = "SELECT valorpar FROM parametros WHERE parametrospar='webhttp'"
Call clsDb.buscar_entabla("general", sql, False, vvalor)
strHttp = Trim(vvalor(0))

If Len(strTenant) = 0 Or Len(strKey) = 0 Or Len(strHttp) = 0 Then
   Call clsGral.escribirlog("Error en la configuración de los parámetros - webTenant, webKey, webHttp", mArchLog)
   GoTo fsalir
End If

'Inicializo y obtengo el identificador
'-------------------------------------
Set req = CreateObject("WINHTTP.WinHTTPRequest.5.1")
req.Open "GET", strHttp, False
req.SetRequestHeader "User-Agent", "Openinflex"
req.SetRequestHeader "Tenant", strTenant
req.SetRequestHeader "Api-Key", strKey
req.Send
If req.Status = 200 Then
   identificador = req.responsetext
   identificador = Mid(identificador, 18)
   identificador = Mid(identificador, 1, Len(identificador) - 2)
Else
   Call clsGral.escribirlog(req.responsetext, mArchLog)
   GoTo fsalir
End If

If Len(identificador) > 0 Then
   'Transfiero los productos
   '-------------------------------------
   req.Open "POST", strHttp & "/" & identificador, False
   req.SetRequestHeader "User-Agent", "Openinflex"
   req.SetRequestHeader "Tenant", strTenant
   req.SetRequestHeader "Api-Key", strKey
   req.SetRequestHeader "Content-Type", "application/json"

   'Agregar subir por fecha de modificación
   sql = "SELECT codi_art, nomb_art, facturable_art, nomb_cod, imagen FROM articulos, pv_tipoprod " & _
      " WHERE codiartref_art=codi_art AND tipo_art=codi_cod  ORDER BY codi_art"
   cantReg = clsDb.consultar(idAux, sql, False)
   Call clsGral.escribirlog("Se encontraron " & cantReg & " productos a informar ", mArchLog)
   lblMsg = "Se encontraron " & cantReg & " productos a informar"
   If cantReg > 0 Then
      If clsDb.cargarRegistros(idAux, colVar, , True) Then
         For i = 1 To cantReg
            If Not colVar.setearobjactivo(i) Then GoTo ferror
            Call colVar.leer(0, , articulo)
            strArt = strArt & "{" & Chr(34) & "Code" & Chr(34) & ": " & Chr(34) & articulo & Chr(34) & ", "
            Call colVar.leer(1, , valorReg)
            strArt = strArt & Chr(34) & "Name" & Chr(34) & ": " & Chr(34) & Replace(valorReg, Chr(34), "") & Chr(34) & ", "
            strArt = strArt & Chr(34) & "Details" & Chr(34) & ": " & Chr(34) & Chr(34) & ", "
            
            sql = "SELECT precio_ap FROM vartiprevig WHERE codigo_ap='2' AND articulo_ap='" & articulo & "'"
            Call clsDb.buscar_entabla("general", sql, False, vvalor)
            strArt = strArt & Chr(34) & "Prices" & Chr(34) & ": [{" & Chr(34) & "Price" & Chr(34) & ": " & Val(vvalor(0)) & ", " & Chr(34) & "SalePrice" & Chr(34) & ": 0}], "
            
            
            strArt = strArt & Chr(34) & "Variants" & Chr(34) & ": ["
            
            'Talle cod4_art
            strVar = ""
            sql = "SELECT DISTINCT codigo.nomb_cod FROM articulos, pv_tipoprod, codigo " & _
               " WHERE codiartref_art='" & articulo & "' AND tipo_art=pv_tipoprod.codi_cod AND cod4_cod=codigo.tipo_cod AND codigo.codi_cod=cod4_art"
            lcantReg = clsDb.consultar(lidAux, sql, False)
            If lcantReg > 0 Then
               If clsDb.cargarRegistros(lidAux, lcolVar, , True) Then
                  For x = 1 To lcantReg
                     If Not lcolVar.setearobjactivo(x) Then GoTo ferror
                     Call lcolVar.leer(0, , valorReg)
                     strVar = strVar & Chr(34) & valorReg & Chr(34) & ","
                  Next
               End If
            End If
            Call clsDb.destruircons(lidAux)
            If Len(strVar) > 0 Then
               strArt = strArt & "{" & Chr(34) & "Variant" & Chr(34) & ": " & Chr(34) & "Talle" & Chr(34) & ", " & Chr(34) & "OrderedList" & Chr(34) & ": [" & Mid(strVar, 1, Len(strVar) - 1) & "]}"
            End If
            '----------------
            
            'Color cod2_art
            strVar = ""
            sql = "SELECT DISTINCT codigo.nomb_cod FROM articulos, pv_tipoprod, codigo " & _
               " WHERE codiartref_art='" & articulo & "' AND tipo_art=pv_tipoprod.codi_cod AND cod2_cod=codigo.tipo_cod AND codigo.codi_cod=cod2_art"
            lcantReg = clsDb.consultar(lidAux, sql, False)
            If lcantReg > 0 Then
               If clsDb.cargarRegistros(lidAux, lcolVar, , True) Then
                  For x = 1 To lcantReg
                     If Not lcolVar.setearobjactivo(x) Then GoTo ferror
                     Call lcolVar.leer(0, , valorReg)
                     strVar = strVar & Chr(34) & valorReg & Chr(34) & ","
                  Next
               End If
            End If
            Call clsDb.destruircons(lidAux)
            If Len(strVar) > 0 Then
               strArt = strArt & IIf(Right(strArt, 1) = "}", ",", "") & "{" & Chr(34) & "Variant" & Chr(34) & ": " & Chr(34) & "Color" & Chr(34) & ", " & Chr(34) & "OrderedList" & Chr(34) & ": [" & Mid(strVar, 1, Len(strVar) - 1) & "]}"
            End If
            '--------------
            
            'Variante cod3_art
            strVar = ""
            sql = "SELECT DISTINCT codigo.nomb_cod FROM articulos, pv_tipoprod, codigo " & _
               " WHERE codiartref_art='" & articulo & "' AND tipo_art=pv_tipoprod.codi_cod AND cod3_cod=codigo.tipo_cod AND codigo.codi_cod=cod3_art"
            lcantReg = clsDb.consultar(lidAux, sql, False)
            If lcantReg > 0 Then
               If clsDb.cargarRegistros(lidAux, lcolVar, , True) Then
                  For x = 1 To lcantReg
                     If Not lcolVar.setearobjactivo(x) Then GoTo ferror
                     Call lcolVar.leer(0, , valorReg)
                     strVar = strVar & Chr(34) & valorReg & Chr(34) & ","
                  Next
               End If
            End If
            Call clsDb.destruircons(lidAux)
            If Len(strVar) > 0 Then
               strArt = strArt & IIf(Right(strArt, 1) = "}", ",", "") & "{" & Chr(34) & "Variant" & Chr(34) & ": " & Chr(34) & "Variante" & Chr(34) & ", " & Chr(34) & "OrderedList" & Chr(34) & ": [" & Mid(strVar, 1, Len(strVar) - 1) & "]}"
            End If
            '----------------
            strArt = strArt & "],"
            
            strArt = strArt & Chr(34) & "Props" & Chr(34) & ": [], "
            
            'Marca cod1_art
            strVar = ""
            sql = "SELECT DISTINCT codigo.nomb_cod FROM articulos, pv_tipoprod, codigo " & _
               " WHERE codiartref_art='" & articulo & "' AND tipo_art=pv_tipoprod.codi_cod AND cod1_cod=codigo.tipo_cod AND codigo.codi_cod=cod1_art"
            lcantReg = clsDb.consultar(lidAux, sql, False)
            If lcantReg > 0 Then
               If clsDb.cargarRegistros(lidAux, lcolVar, , True) Then
                  For x = 1 To lcantReg
                     If Not lcolVar.setearobjactivo(x) Then GoTo ferror
                     Call lcolVar.leer(0, , valorReg)
                     'strVar = strVar & Chr(34) & valorReg & Chr(34) & ","
                     strVar = strVar & valorReg & ","
                  Next
               End If
            End If
            Call clsDb.destruircons(lidAux)
            If Len(strVar) > 0 Then
               strArt = strArt & Chr(34) & "Brand" & Chr(34) & ": " & Chr(34) & Left(strVar, Len(strVar) - 1) & Chr(34) & ", "
            Else
               strArt = strArt & Chr(34) & "Brand" & Chr(34) & ": null, "
            End If
            '------------------
            
            Call colVar.leer(3, , valorReg)     'tipo de producto
            strArt = strArt & Chr(34) & "Tags" & Chr(34) & ": [" & Chr(34) & Trim(valorReg) & Chr(34) & "], "
            strArt = strArt & Chr(34) & "IsNew" & Chr(34) & ": false, " & Chr(34) & "IsSale" & Chr(34) & ": false, " & Chr(34) & "IsBold" & Chr(34) & ": false, "
            
            Call colVar.leer(2, , valorReg)
            strArt = strArt & Chr(34) & "IsUnavailable" & Chr(34) & ": " & IIf(Val(valorReg) = 0, "true", "false") & ", " & Chr(34) & "IsEnabled" & Chr(34) & ": " & IIf(Val(valorReg) = 0, "false", "true") & ", "
            
            Call colVar.leer(4, , valorReg)     'imagen, saco las barras
            pos = InStr(1, valorReg, "\")
            Do While pos <> 0
               valorReg = Mid(valorReg, pos + 1)
               pos = InStr(1, valorReg, "\")
            Loop
            strArt = strArt & Chr(34) & "Pics" & Chr(34) & ": [" & Chr(34) & valorReg & Chr(34) & "], " & Chr(34) & "Attachs" & Chr(34) & ": []}, "
         
            If i Mod 100 = 0 Then
               strArt = "[" & Mid(strArt, 1, Len(strArt) - 2) & "]"
               req.Send strArt
               If req.Status <> 200 Then
                  Call clsGral.escribirlog(" ERROR " & req.Status & ": " & strArt, mArchLog)
               End If
               strArt = ""
            End If
         Next
      End If
   End If
   Call clsDb.destruircons(idAux)
   
   If cantReg Mod 100 <> 0 Then
      strArt = "[" & Mid(strArt, 1, Len(strArt) - 2) & "]"
      req.Send strArt
      If req.Status <> 200 Then
         Call clsGral.escribirlog(" ERROR " & req.Status & ": " & strArt, mArchLog)
      End If
   End If
   
   'Sincronizo
   req.Open "PUT", strHttp & "/" & identificador, False
   req.SetRequestHeader "User-Agent", "Openinflex"
   req.SetRequestHeader "Tenant", strTenant
   req.SetRequestHeader "Api-Key", strKey
   req.SetRequestHeader "Content-Type", "application/json"
   req.Send
   If req.Status <> 200 Then
      Call clsGral.escribirlog("NO SE PUDO SINCRONIZAR: " & strArt, mArchLog)
   Else
      Call clsGral.escribirlog("SE PUDO SINCRONIZAR EXITOSAMENTE", mArchLog)
   End If
   
   req.Open "GET", strHttp & "/" & identificador, False
   req.SetRequestHeader "User-Agent", "Openinflex"
   req.SetRequestHeader "Tenant", strTenant
   req.SetRequestHeader "Api-Key", strKey
   req.Send
   
   
End If

GoTo fsalir

ferror:
   Call clsGral.perrores(False, "InterfaceArticulos", msg, Err)
   msg = msg & " (" & sql & ")"
   Call clsGral.escribirlog(msg, mArchLog)

fsalir:
   Set colVar = Nothing
   Set lcolVar = Nothing
   Set req = Nothing

End Sub
