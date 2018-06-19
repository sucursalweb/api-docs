var DBFFile = require('dbffile');
var rp = require('request-promise-native');

// https://github.com/mongodb-js/mongodb-core/issues/29
process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";
//

const TENANT = 'demo-tenant';
const APIKEY = 'YOUR-API-KEY'

var tags = [];

var batch = [];

var codes = [];

getTags(tags);

DBFFile.open('files/ARTICULO.DBF')
.then(dbf => {
    console.log(`DBF file contains ${dbf.recordCount} rows.`);
    console.log(`Field names: ${dbf.fields.map(f => f.name)}`);
    return dbf.readRecords();
})
.then(rows => {
    rows.forEach(row => {
        var doubled = false;
        if (row["ACTIVO"] !== 'S' && row["WEB"] !== 'S') return;

        var BreakException = {};

        try {
            codes.forEach(c => {
                if (c == row["CODIGO"].trim()) {
                    doubled = true;
                    throw BreakException;
                }
            });
        } catch (e) {
            if (e !== BreakException) throw e;
        }

        if (!doubled) {
            codes.push(row["CODIGO"].trim());

            var candidate = getJsonObjectFromRow(row);
            batch.push(candidate);
        }
    });
    console.log('Batch count: ' + batch.length);
    // batch.sort(function(a, b) {
    //     var textA = a.Code.toUpperCase();
    //     var textB = b.Code.toUpperCase();
    //     return (textA < textB) ? -1 : (textA > textB) ? 1 : 0;
    // });
    // batch.forEach(b=>console.log(b.Code));
    sync(batch);
})
.catch(err => console.log('An error occurred: ' + err))

function getTags(tags) {
    DBFFile.open('files/TABLAS.DBF')
    .then(dbf => {
        console.log(`DBF file contains ${dbf.recordCount} rows.`);
        console.log(`Field names: ${dbf.fields.map(f => f.name)}`);
        return dbf.readRecords();
    })
    .then(rows => {
        rows.forEach(row => {
            if (row["DESCRIP"] === '') return;
            switch(row["TABLA"]){
                case 14:
                    tags.push({
                        tipo: 'MA',
                        codigo: row["CODIGO"],
                        nombre: row["DESCRIP"]
                    });
                    break;
                case 16:
                    tags.push({
                        tipo: 'CL',
                        codigo: row["CODIGO"],
                        nombre: row["DESCRIP"]
                    });
                    break;
                case 13:
                    tags.push({
                        tipo: 'RU',
                        codigo: row["CODIGO"],
                        nombre: row["DESCRIP"]
                    });
                    break;
                case 15:
                    tags.push({
                        tipo: 'ET',
                        codigo: row["CODIGO"],
                        nombre: row["DESCRIP"]
                    });
                    break;
                default:
            }
        });
        console.log(tags.length);
    })
    .catch(err => console.log('An error occurred: ' + err));
    
}

function getJsonObjectFromRow(row) {
    return {
        "Code": row["CODIGO"],
        "Name": row["DESCRIP"],
        "Details": null,
        "Prices": [
            {
            "Price": Number(row["PRECIO1"] || 0) * 1.105, // precio + IVA (impuesto)
            "SalePrice": 0
            },
            {
            "Price": Number(row["PRECIO2"], 0) * 1.105, // precio + IVA (impuesto)
            "SalePrice": 0
            }
        ],
        "Variants": getVariantsFromObject(row),
        "Props": [],
        "Brand": getBrandFromObject(row, tags),
        "Tags": getTagsArrayFromObject(row),
        "IsNew": row["NOVEDAD"] === 'N'?false:true,
        "IsSale": row["OFERTA"] === 'N'?false:true,
        "IsBold": false,
        "IsUnavailable": row["PROXIMO"] === 'S'?true:false,
        "IsEnabled": row["WEB"] === 'N'?false:true,
        "Pics": [`${row["IMAGEN"]}.jpg`],
        "Attachs": []
    };
}

function getBrandFromObject(row, tags) {
    var result = '';
    if (row["MARCA"] > 0) {
        tags.forEach((t)=>{
            if (t.tipo === "MA" && t.codigo == row["MARCA"]){
                result = `${t.codigo}|${t.nombre}`;
            }
        });
    }

    return result;
}

function getVariantsFromObject(row) {
    var variants = [
        {
            kind: "Color",
            short: "C"
        },
        {
            kind: "Talle",
            short: "T"
        }
    ];
    var elements = [];
    
    var result = variants.map((v)=>{
        [1,2,3,4,5,6,7,8,9].forEach((e)=>{
            let i = `${v.short}${e}`;
            if (row[i]!=='') elements.push(row[i])
        });

        let list = elements;
        elements = [];

        return {
            Variant: v.kind,
            OrderedList: list
        };
    });
    
    return result;
}

function getTagsArrayFromObject(row) {
    let result = [];
    if (row["CATEGORIA"] > 0){
        tags.forEach((t)=> {
            if (t.tipo === "CL" && t.codigo == row["CATEGORIA"]){
                result.push(`${t.codigo}|${t.nombre}`);
            }
        });
    }

    if (row["RUBRO"] > 0){
        tags.forEach((t)=> {
            if (t.tipo === "RU" && t.codigo == row["RUBRO"]){
                result.push(`${t.codigo}|${t.nombre}`);
            }
        });
    }

    if (row["ETIQUETA"] > 0){
        tags.forEach((t)=> {
            if (t.tipo === "ET" && t.codigo == row["ETIQUETA"]){
                result.push(`${t.codigo}|${t.nombre}`);
            }
        });
    }

    return result;
}

var syncId = '';
const swioApiHost = 'https://api.sucursalweb.io';

function sync(batch) {
  var options = {
    uri: `${swioApiHost}/v1/sync`,
    headers: {
        'User-Agent': 'Node Sample Sucursal Web Client v1.0.0',
        'Api-Key': APIKEY,
        'Tenant': TENANT
    },
    json: true
  };

  rp(options)
    .then(function(data) {
        console.log(`Sync identifier: ${data.identifierId}`);
        syncId = data.identifierId;
    })
    .then(function() {
        var optionsPost = {
            method: 'POST',
            uri: `${swioApiHost}/v1/sync/${syncId}`,
            headers: {
                'User-Agent': 'Node Sample Sucursal Web Client v1.0.0',
                'Api-Key': APIKEY,
                'Tenant': TENANT
            },
            body: batch,
            json: true
        };
        return rp(optionsPost)
    })
    .then(function(data){
      console.log(data.msg);
    })
    .then(function() {
      var optionsPut = {
          method: 'PUT',
          uri: `${swioApiHost}/v1/sync/${syncId}`,
          headers: {
              'User-Agent': 'Node Sample Sucursal Web Client v1.0.0',
              'Api-Key': APIKEY,
              'Tenant': TENANT
          },
          json: true
      };
      return rp(optionsPut)
    })
    .then(function(data){
      console.log(data.status);
    })
    .catch(function(err){
        // API call failed... Do something
        console.error(err);
    });
}