import json
import urllib3

def lambda_handler(event, context):
    http = urllib3.PoolManager()
    url_cisa = "https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json"
     
    try:
        # Llamada segura servidor-servidor a CISA (Sin problemas de CORS)
         response = http.request('GET', url_cisa)
         data = json.loads(response.data.decode('utf-8'))
         
        # Extraemos y filtramos Ãºnicamente las primeras 5 vulnerabilidades
         vulnerabilities = data.get('vulnerabilities', [])
         resultado = {
             "amenazas": vulnerabilities[:5]
         }
    except Exception as e:
        resultado = {"error": f"Fallo al consultar CISA: {str(e)}"}
        status_code = 500
 
    # Retornamos con headers explÃ­citos para el navegador
    return {
         'statusCode': status_code,
         'headers': {

            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, OPTIONS, POST',
            'Content-Type': 'application/json'
         },
         'body': json.dumps(resultado)
    }