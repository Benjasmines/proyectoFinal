import json
import boto3
import os

s3 = boto3.client('s3')
BUCKET_NAME = os.environ.get('BUCKET_NAME')

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, hx-request, hx-target, hx-current-url, hx-trigger, X-Amz-Date, Authorization, X-Api-Key, X-Amz-Security-Token"
}


def lambda_handler(event, context):
    method = event.get('httpMethod') or event.get('requestContext', {}).get('http', {}).get('method', '')
    # Manejo de CORS preflight request
    if method == 'OPTIONS':
        return {
            "statusCode": 200,
            "headers": CORS_HEADERS,
            "body": ""
        }

    try:
        #Listar los archivos en la carpeta de reservas
        response = s3.list_objects_v2(Bucket=BUCKET_NAME, Prefix='reservas/')

        html_rows = ""

        if 'Contents' in response:
            # Ordenar por fecha de modificaciÃ³n (mÃ¡s recientes primero)
            archivos = sorted(response['Contents'], key=lambda x: x['LastModified'], reverse=True)

            for item in archivos:
                # Leer cada archivo JSON
                file_obj = s3.get_object(Bucket=BUCKET_NAME, Key=item['Key'])
                file_content = file_obj['Body'].read().decode('utf-8')
                data = json.loads(file_content)

                # Construir una fila HTML para la tabla del Admin
                html_rows += f"""
                <tr class="border-b border-white/10 hover:bg-white/5 transition">
                    <td class="p-3 text-white">{data.get('timestamp', '')}</td>
                    <td class="p-3 text-cyber font-mono">{data.get('nombre', '')}</td>
                    <td class="p-3 text-gray-400">{data.get('email', '')}</td>
                    <td class="p-3 text-white">{data.get('fecha', '')} a las {data.get('hora', '')}</td>
                </tr>
                """
        else:
            html_rows = "<tr><td colspan='4' class='p-4 text-center text-gray-500'>No hay reservas pendientes.</td></tr>"

        # Devolver el HTML directamente al frontend
        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "text/html",
                **CORS_HEADERS
            },
            "body": html_rows
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "text/html",
                **CORS_HEADERS
            },
            "body": f"<tr><td colspan='4' class='p-4 text-center text-cyber'>Error cargando datos: {str(e)}</td></tr>"
        }