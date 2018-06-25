var BASEURL = 'https://api.sucursalweb.io/v1';

var TENANT = 'demo-tenant';
var APIKEY = 'YOUR-API-KEY';

function onOpen() {
  var spreadsheet = SpreadsheetApp.getActive();
  var menuItems = [
    {name: 'Sicronizar...', functionName: 'synchronize_'}
  ];
  spreadsheet.addMenu('Sucursal Web', menuItems);
}

function synchronize_() {
  Logger.log('Solicitando Sincronización...');
  var options = {
    'contentType': 'application/json',
    'headers': {
      'User-Agent': 'Google App Script Sample Sucursal Web Client v1.0.0',
      'Tenant': TENANT,
      'Api-Key': APIKEY
    }
  }
  var result = JSON.parse(UrlFetchApp.fetch(BASEURL + '/sync' , options).getContentText());
  Logger.log(result);
  
  // TODO: based on the received "identifier", upload data and initialize/ask-for a Sync
  
  //
  // Incomplete sample for challenge...
  //
  // Read:
  //        https://developers.google.com/apps-script/guides/sheets
  //        https://developers.google.com/apps-script/guides/sheets/functions
  //        https://developers.google.com/apps-script/quickstart/macros
  //        https://developers.google.com/apps-script/reference/url-fetch/url-fetch-app
  //        https://webapps.stackexchange.com/questions/33164/is-it-possible-to-use-google-spreadsheets-to-post-to-a-web-service

}