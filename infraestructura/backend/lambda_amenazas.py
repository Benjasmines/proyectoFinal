import json
import urllib3 

def lambda_handler(event, context):
    # 1. Tu Lambda se conecta a CISA (esto el navegador no puede hacerlo)
    http = urllib3.PoolManager()
    url_cisa = "https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json"
    
    response = http.request('GET', url_cisa)
    data = json.loads(response.data.decode('utf-8'))
    
    # 2. Aquí filtras lo que quieras devolver al frontend
    resultado = {
        "amenazas": data.get('vulnerabilities', [])[:5] # Solo las primeras 5
    }
    
    # 3. Devuelves la respuesta al API Gateway con los headers necesarios
    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Origin': '*', # ¡Esto soluciona el CORS!
            'Content-Type': 'application/json'
        },
        'body': json.dumps(resultado)
    }