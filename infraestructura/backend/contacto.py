import json
import boto3
import os
from urllib.parse import parse_qs
from datetime import datetime

s3 = boto3.client('s3')
BUCKET_NAME = os.environ.get('BUCKET_NAME')
 
def lambda_handler(event, context):
    print("========== MOMENTO DEBUGGG ==========")
    print("========== NUEVA INVOCACIÃ“N DE LAMBDA ==========")
    print(f"[LOG] Evento crudo (raw event) recibido: {json.dumps(event)}")

    method = event.get('httpMethod') or event.get('requestContext', {}).get('http', {}).get('method', '')
    print(f"[LOG] MÃ©todo HTTP detectado: {method}")

    # Cabeceras CORS unificadas y robustas (mayÃºsculas y permitiendo cabeceras de AWS y HTMX)
    cors_headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS, GET",
        "Access-Control-Allow-Headers": "Content-Type, accept, hx-request, hx-target, hx-current-url, hx-trigger, hx-trigger-name, hx-prompt, X-Amz-Date, Authorization, X-Api-Key, X-Amz-Security-Token"
    }

    if method == 'OPTIONS':
        print("[LOG] Interceptada peticiÃ³n OPTIONS (Preflight). Respondiendo con cabeceras CORS de Ã©xito.")
        return {
            "headers": cors_headers,
            "body": ""
         }
        
    try:
        path = event.get('rawPath') or event.get('path', '')
        print(f"[LOG] Path de ejecuciÃ³n: {path}")
        body_str = event.get('body', '')
        if event.get('isBase64Encoded', False):
            import base64
            body_str = base64.b64decode(body_str).decode('utf-8')

        print(f"[LOG] Body decodificado como string: {body_str}")
        
        parsed_params = parse_qs(body_str)
        data = {k: v[0] for k, v in parsed_params.items()}
        print(f"[LOG] Diccionario de datos extraÃ­dos: {json.dumps(data)}")
        timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')

        # ==========================================
        # FLUJO A: PROCESAR RESERVA
        # ==========================================
        if 'reserva' in path:
            print("[LOG] Entrando a la ruta de RESERVA")
            nombre = data.get('nombre', 'Operador_AnÃ³nimo')
            email = data.get('email', 'secure@email.com')
            fecha = data.get('fecha', 'Sin fecha')
            hora = data.get('hora', 'Sin hora')
            
            # El nombre del archivo bloquea la fecha y hora.
            # Limpiamos caracteres problemÃ¡ticos por seguridad (barras o dos puntos)
            safe_fecha = fecha.replace("/", "-")
            safe_hora = hora.replace(":", "-")
            file_name = f"reservas/{safe_fecha}_{safe_hora}.json"
            
            # Barrera para ver si el horario estÃ¡ disponible (head_object)
            try:
                print(f"[LOG] Verificando disponibilidad del slot: {file_name}")
                s3.head_object(Bucket=BUCKET_NAME, Key=file_name)
                
                # Si el cÃ³digo logra ejecutar la lÃ­nea de arriba y pasa aquÃ­, EL ARCHIVO YA EXISTE
                print("[LOG] ALERTA: El horario ya estÃ¡ reservado.")
                return {
                    "statusCode": 409,
                    "headers": {
                        "Content-Type": "text/html",
                        **cors_headers
                    },
                    "body": f"""
                    <div class="p-4 bg-red-900/20 border border-cyber text-cyber rounded font-mono text-sm mb-6">
                        <p class="font-bold">[-] ERROR_CONFLICTO</p>
                        <p class="mt-1">El horario del <span class="text-white">{fecha}</span> a las <span class="text-white">{hora}</span> ya ha sido asegurado por otro operador.</p>
                        <p class="text-xs mt-2 text-gray-500">Por favor, seleccione un parÃ¡metro de tiempo distinto.</p>
                    </div>
                    """
                }
            except s3.exceptions.ClientError as e:
                # Si el error es '404', significa que no se encontrÃ³ el archivo. El horario estÃ¡ libre.
                if e.response['Error']['Code'] == '404':
                    print("[LOG] Horario disponible. Procediendo a guardar...")
                else:
                    # Si falla por un error de permisos u otra cosa, lanzamos el error general
                    raise e
            
            # Guardar la reserva en S3
            s3_data = {
                "tipo": "reserva", "nombre": nombre, "email": email, 
                "fecha": fecha, "hora": hora, "timestamp": timestamp
            }
            
            print(f"[LOG] Intentando subir a S3 en el bucket {BUCKET_NAME} con la key {file_name}")
            s3.put_object(
                Bucket=BUCKET_NAME,
                Key=file_name,
                Body=json.dumps(s3_data, indent=2, ensure_ascii=False),
                ContentType='application/json'
            )

            print("[LOG] Subida a S3 EXITOSA. Retornando HTML al cliente.")
            
            return {
                "statusCode": 200,
                "headers": {
                    "Content-Type": "text/html",
                    **cors_headers,
                    "HX-Redirect": "purchases.html" 
                },
                "body": f"""
                <div class="p-4 bg-terminal/10 border border-terminal text-terminal rounded font-mono text-sm mb-6">
                    <p class="font-bold">[+] CONEXIÃ“N_ESTABLECIDA_RESERVA</p>
                    <p class="mt-1">DÃ­a: <span class="text-white">{fecha}</span> | Hora de inicio: <span class="text-white">{hora} CLST</span></p>
                    <p class="text-xs text-gray-500 mt-2">ID_TRANSACCIÃ“N: {timestamp} | Operador: {nombre}</p>
                </div>
                """
            }

        # ==========================================
        # FLUJO B: PROCESAR CONTACTO
        # ==========================================
        else:
            print("[LOG] Entrando a la ruta por defecto (CONTACTO)")
            # ... (cÃ³digo existente del flujo B) ...
            nombre = data.get('nombre', 'Operador_AnÃ³nimo')
            empresa = data.get('empresa', 'No especificada')
            asunto = data.get('asunto', 'Consulta general')
            mensaje = data.get('mensaje', '')
            
            file_name = f"contactos/{timestamp}_{nombre}.json"
            s3_data = {
                "tipo": "contacto", "nombre": nombre, "empresa": empresa,
                "asunto": asunto, "mensaje": mensaje, "timestamp": timestamp
            }
            
            s3.put_object(
                Bucket=BUCKET_NAME,
                Key=file_name,
                Body=json.dumps(s3_data, indent=2, ensure_ascii=False),
                ContentType='application/json'
            )
            
            return {
                "statusCode": 200,
                "headers": {
                    "Content-Type": "text/html",
                    **cors_headers
                },
                "body": f"""
                <div class="p-4 bg-terminal/10 border border-terminal text-terminal rounded font-mono text-sm mb-6">
                    <p class="font-bold">[+] MENSAJE_TRANSMITIDO</p>
                    <p class="mt-1">Operador: <span class="text-white">{nombre}</span></p>
                    <p class="text-xs text-gray-500 mt-2">ID_TRANSACCIÃ“N: {timestamp}</p>
                </div>
                """
            }

    # Agregamos todas las cabeceras CORS en el bloque de excepciones por si el servidor falla y arroja 500
    except Exception as e:
        print(f"[ERROR CRÃTICO] Hubo una excepciÃ³n en el cÃ³digo: {str(e)}")
        return {
            "statusCode": 500,
            "headers": cors_headers,
            "body": f"<p style='color:red;'>Error interno del servidor: {str(e)}</p>"
        }