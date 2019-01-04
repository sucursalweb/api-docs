# Usando NodeJS para Sincronizar DBFs con #sucursalweb

### Requisitos

* NodeJS: https://nodejs.org/en/
* Paquete Node-dbf: https://www.npmjs.com/package/node-dbf

Indica el Tenant y el Api-Key obtenidos desde la Consola.

```
const TENANT = 'demo-tenant';
const APIKEY = 'YOUR-API-KEY';
```

Esta demo simula un sistema que almacena datos en archivos DBF, siguiendo estas especificaciones de alto nivel (los detalles de cada archivo, se describen en el programa (https://github.com/sucursalweb/api-docs/blob/master/samples/dbf-node/index.js)

* **ARTICULO.DBF** - los articulos, con sus precios, categorías y otros datos relevantes.
* **TABLAS.DBF** - esta, es una tabla de apoyo, que contiene datos con los nombres y codigos de categorías (Rubros, Marcas y otras)

El programa, sigue la secuencia de llamadas para la API Batch, [como se detalla acá](https://github.com/sucursalweb/api-docs#api-bulk-1)
