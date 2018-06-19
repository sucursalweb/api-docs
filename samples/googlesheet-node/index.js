const fs = require('fs');
const readline = require('readline');
const {google} = require('googleapis');
var rp = require('request-promise-native');

// https://github.com/mongodb-js/mongodb-core/issues/29
process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";
//

// If modifying these scopes, delete credentials.json.
const SCOPES = ['https://www.googleapis.com/auth/spreadsheets.readonly'];
const TOKEN_PATH = 'credentials.json';

const TENANT = 'demo-tenant';
const APIKEY = 'YOUR-API-KEY'

// Publicly viewable Google Sheet created for the purpose of this demo.
const spreadsheetId = '1L1HFT3ZahxBuNt2lnr8IqyB0_Cq-15Epu-GgSXa97J8';
//

// Load client secrets from a local file.
fs.readFile('client_secret.json', (err, content) => {
  if (err) return console.log('Error loading client secret file:', err);
  // Authorize a client with credentials, then call the Google Sheets API.
  authorize(JSON.parse(content), listMajors);
});

/**
 * Create an OAuth2 client with the given credentials, and then execute the
 * given callback function.
 * @param {Object} credentials The authorization client credentials.
 * @param {function} callback The callback to call with the authorized client.
 */
function authorize(credentials, callback) {
  const {client_secret, client_id, redirect_uris} = credentials.installed;
  const oAuth2Client = new google.auth.OAuth2(
      client_id, client_secret, redirect_uris[0]);

  // Check if we have previously stored a token.
  fs.readFile(TOKEN_PATH, (err, token) => {
    if (err) return getNewToken(oAuth2Client, callback);
    oAuth2Client.setCredentials(JSON.parse(token));
    callback(oAuth2Client);
  });
}

/**
 * Get and store new token after prompting for user authorization, and then
 * execute the given callback with the authorized OAuth2 client.
 * @param {google.auth.OAuth2} oAuth2Client The OAuth2 client to get token for.
 * @param {getEventsCallback} callback The callback for the authorized client.
 */
function getNewToken(oAuth2Client, callback) {
  const authUrl = oAuth2Client.generateAuthUrl({
    access_type: 'offline',
    scope: SCOPES,
  });
  console.log('Authorize this app by visiting this url:', authUrl);
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  rl.question('Enter the code from that page here: ', (code) => {
    rl.close();
    oAuth2Client.getToken(code, (err, token) => {
      if (err) return callback(err);
      oAuth2Client.setCredentials(token);
      // Store the token to disk for later program executions
      fs.writeFile(TOKEN_PATH, JSON.stringify(token), (err) => {
        if (err) console.error(err);
        console.log('Token stored to', TOKEN_PATH);
      });
      callback(oAuth2Client);
    });
  });
}

/**
 * Prints the names and majors of students in a sample spreadsheet:
 * @see https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit
 * @param {google.auth.OAuth2} auth The authenticated Google OAuth client.
 */
function listMajors(auth) {
  const sheets = google.sheets({version: 'v4', auth});
  sheets.spreadsheets.values.get({
    spreadsheetId: spreadsheetId,
    range: 'Productos!A2:Y',
  }, (err, {data}) => {
    if (err) return console.log('The API returned an error: ' + err);
    const rows = data.values;
    if (rows.length) {
      console.log('Code, Name, Price1:');
      // Print columns A and Y, which correspond to indices 0 and whtever...
      let batch = [];
      rows.map((row) => {
        console.log(`${row[0]}, ${row[1]}, ${row[2]}`);
        batch.push(getJsonObjectFromRow(row));
      });
      sync(batch);
    } else {
      console.log('No data found.');
    }
  });
}

function getJsonObjectFromRow(row) {
    return {
        "Code": row[0],
        "Name": row[1],
        "Details": null,
        "Prices": [
          {
            "Price": Number((row[2] === '#N/A'?0:row[2]) || 0),
            "SalePrice": 0
          },
          {
            "Price": 0,
            "SalePrice": 0
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
            "Value": "sin-asignar"
          }
        ],
        "Brand": row[12] !== ''? row[12] : null,
        "Tags":["AGUJAS","BROCHES"],
        "IsNew": Boolean(row[18] === ''?0:Number(row[18])),
        "IsSale": Boolean(row[19] === ''?0:Number(row[19])),
        "IsBold": Boolean(row[20] === ''?0:Number(row[20])),
        "IsUnavailable": Boolean(row[21] === ''?0:Number(row[21])),
        "IsEnabled": Boolean(row[22] === ''?0:Number(row[22])),
        "Pics": [],
        "Attachs": []
      }
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