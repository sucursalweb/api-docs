# Documentación y ejemplos para las APIs de Sucursal Web
Clientes en distintos *stacks* para que puedas integrar informacion desde y hacia tu #sucursalweb.

## Tipos de API
Las distintas APIs que presentamos, para que puedas interactuar con tu [#sucursalweb](https://www.sucursalweb.io) de las formas en las que necesites.

### API Bulk
La razon por la que creamos esta API, es para que ERPs (o Software de Gestión, o de Facturación, o de Stock. "Se los llama de muchas formas") puedan actualizar todo el catálogo en forma masiva.

### API Transaccional
Para realizar operaciones "conversacionales" con tu Tienda, que te faciliten integrarla con tus sistemas de *back-end*. Algunos ejemplos:

* Listar ordenes recibidas
* Obtener los datos de un cliente
* Obtener los datos de un pedido

## Antes de empezar
Algunos tips importantes, para evitarte problemas a la hora de codear :)

### TLS
La API solo está expuesta vía [TLS](https://en.wikipedia.org/wiki/Transport_Layer_Security), con lo cual todas las llamadas que no sean "http**s**://" van a ser descartadas.\

### Tamaño del BODY
En llamadas a la API (ej. Métodos de tipo "POST"), no debe superar los 10MB o va a ser rechazado (algunas operaciones, permiten rodear este límite, gracias al envío de lotes.

### Autenticación
Todas las llamadas tienen que identificarse informando el "Tenant" y la "Api-Key" que le corresponden a tu #sucursalweb.

```
curl -H 'User-Agent: Pure HTTP client v1.0' /
    -H 'Api-Key: [YOUR_VALID_API_KEY]' /
    -H 'Tenant: [YOUR-TENANT]' /
  https://api.sucursalweb.io/[...]
```

## Ejemplos
Acá, un listado de los que hay hasta ahora. Aceptamos contribuciones :)

* Llamadas HTTP (elemental)
* Integración entre Google Sheets y la API Bulk para Sincronizaciones. [Ver sample](https://github.com/sucursalweb/api-docs/tree/master/samples/googlesheet-node) hecho en NodeJS
* Sincronizar masivamente Sistemas que usan archivos DBF ([dBASE III](https://es.wikipedia.org/wiki/DBase#dBASE_III)) para el almacenamiento de datos. [Ver sample](https://github.com/sucursalweb/api-docs/tree/master/samples/dbf-node) hecho en NodeJS
* **challenge!** También usando Google Sheets, pero esta integración Full Cloud, te permite agregar un menú a la planilla y Sincronizar desde ahí mismo. Es ideal para clientes que quieran resolver desde la planilla, en un click (o tap, ya que también funciona en la App de Google Sheets :). Este ejemplo esta incompleto, y es parte de nuestra serie de *challenges* ideales para una hackaton! [Ver sample](https://github.com/sucursalweb/api-docs/tree/master/samples/googlesheet-menu)

### Llamadas HTTP
Aca podes aprender como las formas de comunicarte directamente con la API, hablando HTTP puro, sin librerías, lenguajes ni *Frameworks*. Estas llamadas, ayudan a entender los flujos y detalles de las distintas *conversaciones* que tengas con la API de [#sucursalweb](https://twitter.com/sucursalwebio)

#### API Bulk
El objetivo es mantener de forma masiva **todos** los productos de tu catálogo. Está preparada para trabajar con docenas, cientos o miles de actualizaciones, permitiendo poner al día todo tu catálogo, con un minimo esfuerzo.

**Flujo:** para iniciar una Sincronización a través de la API Bulk, hay que hacer las siguientes operaciones en el orden indicado:

1. Inicializar y obtener un *Identificador* que te sirve para el resto de las operaciones.
2. Subir un lote (si tenes miles de productos, te sugerimos crear lotes de 1000, y subirlos uno detrás del otro, repitiendo la operación. Por ejemplo: si tenes 5000 productos, subís 5 lotes de 1000 productos cada uno)
3. Solicitar una Sincronización
4. Obtener el estado de la Sincronización (**poll**)

##### 1. Inicializar y obtener un *Identificador*
```
curl -H 'User-Agent: Pure HTTP client v1.0' /
    -H 'Api-Key: [YOUR_VALID_API_KEY]' /
    -H 'Tenant: [YOUR-TENANT]' /
  https://api.sucursalweb.io/v1/sync
```

##### 2. Subir un lote
```
lote1='[{
        "Code": "P0001",
        "Name": "Producto de ejemplo 1",
        "Details": null,
        "Prices": [
          {
            "Price": 5,
            "SalePrice": 0
          },
          {
            "Price": 8,
            "SalePrice": 7
          }
        ],
        "Variants": [
          {
            "Variant": "Color",
            "OrderedList": ["Negro","Blanco"]
          },
          {
            "Variant": "Talle",
            "OrderedList": ["S","M","L"]
          }
        ],
        "Props": [
          {
            "Prop": "Trama",
            "Value": "Liso"
          },
          {
            "Prop": "Catalogo",
            "Value": "Pag. 3"
          }
        ],
        "Brand": null,
        "Tags":["RUBRO A","RUBRO B","DIA DEL PADRE"],
        "IsNew": 0,
        "IsSale": 1,
        "IsBold": 0,
        "IsUnavailable": 0,
        "IsEnabled": 1,
        "Pics": [],
        "Attachs": []
      }]'

curl -H 'User-Agent: Pure HTTP client v1.0' /
    -H 'Api-Key: [YOUR_VALID_API_KEY]' /
    -H 'Tenant: [YOUR-TENANT]' /
    -H 'Content-Type: application/json' /
    -X POST /
    -data $lote1 /
  https://api.sucursalweb.io/v1/sync/[IDENTIFICADOR]
```

##### 3. Solicitar una Sincronización
```
curl -H 'User-Agent: Pure HTTP client v1.0' /
    -H 'Api-Key: [YOUR_VALID_API_KEY]' /
    -H 'Tenant: [YOUR-TENANT]' /
    -H 'Content-Type: application/json' /
    -X PUT /
  https://api.sucursalweb.io/v1/sync/[IDENTIFICADOR]
```

##### 4. Obtener el estado de la Sincronización
```
curl -H 'User-Agent: Pure HTTP client v1.0' /
    -H 'Api-Key: [YOUR_VALID_API_KEY]' /
    -H 'Tenant: [YOUR-TENANT]' /
  https://api.sucursalweb.io/v1/sync/[IDENTIFICADOR]
```

#### API Transaccional

##### Listar ordenes recibidas
Esta operación permite traer un listado con las órdenes (pedidos) recibidas el día anterior (ver opciones), en una sola acción.

**Opciones:**

* Se puede indicar opcionalmente, la cantidad de días hacia atrás ([days=1..7]). El valor máximo es de 7. Si no se indica, se trae información del día anterior (days=1).
* Solo se listaran aquellas órdenes que hayan sido "colocadas" y no hayan pasado a otro estado.
* Se sugiere usar este listado como apoyo diario para conciliar los pedidos recibidos
* **Tiempo Real:** se pueden usar las notificaciones que se envían por correo electrónico a tal fin.

```
curl -H 'User-Agent: Pure HTTP client v1.0' /
    -H 'Api-Key: [YOUR_VALID_API_KEY]' /
    -H 'Tenant: [YOUR-TENANT]' /
  https://api.sucursalweb.io/v1/order/list[?days=1..7]  
```

##### Obtener los datos de un cliente
(documentación pendiente) (ver https://github.com/australcommerce/api#recuperar-un-cliente)
##### Obtener los datos de un pedido
(documentación pendiente) (ver https://github.com/australcommerce/api#orden)
