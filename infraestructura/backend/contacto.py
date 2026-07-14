import json
import os
import boto3
import urllib.parse
from datetime import datetime
import uuid

# Cliente de S3 (boto3 ya viene instalado en AWS Lambda)
s3_client = boto3.client('s3')

def lambda_handler(event, context):
    # 1. Leer el nombre del bucket desde las variables de entorno de Terraform
    bucket_name = os.environ.get('BUCKET_NAME')
    
    try:
        # 2. Extraer los datos enviados por el usuario
        # HTMX normalmente envía los formularios como texto plano (URL-encoded) o JSON
        body = event.get('body', '')
        
        # Intentamos leerlo como JSON, si falla lo leemos como formulario HTML clásico
        try:
            datos_formulario = json.loads(body)
        except:
            datos_formulario = dict(urllib.parse.parse_qsl(body))
            
        if not datos_formulario:
            raise ValueError("No se recibieron datos en el formulario")

        # 3. Crear un nombre de archivo único con la fecha de hoy
        # Ejemplo: contacto_20260714_1644_a1b2c3d4.json
        fecha_str = datetime.now().strftime("%Y%m%d_%H%M")
        id_unico = str(uuid.uuid4())[:8]
        nombre_archivo = f"contacto_{fecha_str}_{id_unico}.json"
        
        # 4. Guardar los datos en el bucket de S3
        s3_client.put_object(
            Bucket=bucket_name,
            Key=nombre_archivo,
            Body=json.dumps(datos_formulario, indent=4),
            ContentType='application/json'
        )
        
        # 5. Responder al frontend con un mensaje de éxito (Compatible con HTMX)
        html_exito = """
        <div class="p-4 bg-green-900/40 border border-green-500 rounded-lg text-center">
            <h3 class="text-green-400 font-mono font-bold">✓ Transmisión Exitosa</h3>
            <p class="text-gray-300 text-sm mt-2">Hemos recibido tu mensaje en nuestro nodo seguro. Te contactaremos pronto.</p>
        </div>
        """
        
        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "text/html",
                "Access-Control-Allow-Origin": "*"
            },
            "body": html_exito
        }
        
    except Exception as e:
        print(f"Error procesando contacto: {str(e)}")
        # Mensaje de error para el frontend
        html_error = """
        <div class="p-4 bg-red-900/40 border border-red-500 rounded-lg text-center">
            <h3 class="text-red-400 font-mono font-bold">⚠ Fallo de Conexión</h3>
            <p class="text-gray-300 text-sm mt-2">No pudimos procesar tu solicitud. Por favor intenta de nuevo.</p>
        </div>
        """
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "text/html",
                "Access-Control-Allow-Origin": "*"
            },
            "body": html_error
        }