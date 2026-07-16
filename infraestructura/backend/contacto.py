import json
import boto3
import os
from urllib.parse import parse_qs
from datetime import datetime

s3 = boto3.client('s3')
BUCKET_NAME = os.environ.get('BUCKET_NAME')

def lambda_handler(event, context):
    # 1. Identificar desde qué endpoint viene la petición en API Gateway
    path = event.get('rawPath') or event.get('path', '')
    
    # 2. Obtener y parsear el body que envía HTMX (application/x-www-form-urlencoded)
    body_str = event.get('body', '')
    if event.get('isBase64Encoded', False):
        import base64
        body_str = base64.b64decode(body_str).decode('utf-8')
    
    # parse_qs convierte "nombre=Juan&email=test@test.com" en {"nombre": ["Juan"], "email": ["test@test.com"]}
    parsed_params = parse_qs(body_str)
    # Limpiamos las listas para quedarnos con el valor de cada campo
    data = {k: v[0] for k, v in parsed_params.items()}
    
    timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')
    
    # ==========================================
    # FLUJO A: PROCESAR RESERVA
    # ==========================================
    if 'reserva' in path:
        nombre = data.get('nombre', 'Operador_Anónimo')
        email = data.get('email', 'secure@email.com')
        fecha = data.get('fecha', 'Sin fecha')
        hora = data.get('hora', 'Sin hora')
        
        # Guardamos la reserva en una carpeta separada en S3
        file_name = f"reservas/{timestamp}_{nombre}.json"
        s3_data = {
            "tipo": "reserva",
            "nombre": nombre,
            "email": email,
            "fecha": fecha,
            "hora": hora,
            "timestamp": timestamp
        }
        
        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=file_name,
            Body=json.dumps(s3_data, indent=2, ensure_ascii=False),
            ContentType='application/json'
        )
        
        # Respuesta HTML que HTMX inyectará en "#reserva-respuesta"
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "text/html"},
            "body": f"""
            <div class="p-4 bg-terminal/10 border border-terminal text-terminal rounded font-mono text-sm mb-6">
                <p class="font-bold">[+] CONEXIÓN_ESTABLECIDA_RESERVA</p>
                <p class="mt-1">Día: <span class="text-white">{fecha}</span> | Hora de inicio: <span class="text-white">{hora} CLST</span></p>
                <p class="text-xs text-gray-500 mt-2">ID_TRANSACCIÓN: {timestamp} | Operador: {nombre}</p>
            </div>
            """
        }

    # ==========================================
    # FLUJO B: PROCESAR CONTACTO
    # ==========================================
    else:
        nombre = data.get('nombre', 'Operador_Anónimo')
        empresa = data.get('empresa', 'No especificada')
        asunto = data.get('asunto', 'Consulta general')
        mensaje = data.get('mensaje', '')
        
        # Guardamos el contacto en su respectiva carpeta
        file_name = f"contactos/{timestamp}_{nombre}.json"
        s3_data = {
            "tipo": "contacto",
            "nombre": nombre,
            "empresa": empresa,
            "asunto": asunto,
            "mensaje": mensaje,
            "timestamp": timestamp
        }
        
        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=file_name,
            Body=json.dumps(s3_data, indent=2, ensure_ascii=False),
            ContentType='application/json'
        )
        
        # Respuesta HTML que HTMX inyectará en "#form-respuesta"
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "text/html"},
            "body": f"""
            <div class="p-4 bg-terminal/10 border border-terminal text-terminal rounded font-mono text-sm mb-6">
                <p class="font-bold">[+] CANAL_DE_CONTACTO_ESTABLECIDO</p>
                <p class="mt-1">Gracias, {nombre}. Tu reporte/solicitud sobre "{asunto}" ha sido recibido y cifrado.</p>
                <p class="text-xs text-gray-500 mt-2">TICKET_ID: {timestamp}</p>
            </div>
            """
        }