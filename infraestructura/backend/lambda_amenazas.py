import json
import urllib3

def lambda_handler(event, context):
    http = urllib3.PoolManager()
    url_cisa = "https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json"
    
    try:
        # 1. Llamada segura servidor-servidor a CISA (Sin problemas de CORS)
        response = http.request('GET', url_cisa)
        data = json.loads(response.data.decode('utf-8'))
        
        # 2. Extraemos y filtramos únicamente las primeras 5 vulnerabilidades
        vulnerabilities = data.get('vulnerabilities', [])
        resultado = {
            "amenazas": vulnerabilities[:5]
        }
        status_code = 200
        
    except Exception as e:
        resultado = {"error": f"Fallo al consultar CISA: {str(e)}"}
        status_code = 500

    # 3. Retornamos con headers explícitos para el navegador
    return {
        'statusCode': status_code,
        'headers': {
            'Access-Control-Allow-Origin': '*', # Solución definitiva al error de CORS
            'Access-Control-Allow-Methods': 'GET, OPTIONS',
            'Content-Type': 'application/json'
        },
        'body': json.dumps(resultado)
    }