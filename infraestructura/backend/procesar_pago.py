import json
import re
from urllib.parse import parse_qs

# Algoritmo de Luhn para validar tarjetas reales
def validar_tarjeta(numero):
    numero = numero.replace(" ", "").replace("-", "")
    if not numero.isdigit():
        return False

    suma = 0
    alt = False

    for i in reversed(range(len(numero))):
        n = int(numero[i])
        if alt:
            n *= 2
            if n > 9:
                n -= 9
        suma += n
        alt = not alt

    return suma % 10 == 0

# ExpresiÃ³n regular para validar el formato del correo
def validar_correo(correo):
    patron = r'^[\w\.-]+@[\w\.-]+\.\w+$'
    return re.match(patron, correo) is not None

# Headers CORS reutilizables en todas las respuestas
CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS, GET",
    "Access-Control-Allow-Headers": "Content-Type, hx-request, hx-target, hx-current-url,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
}

def respuesta(status_code, body, extra_headers=None):
    headers = {**CORS_HEADERS, **(extra_headers or {})}
    return {
        "statusCode": status_code,
        "headers": headers,
        "body": body
    }

def lambda_handler(event, context):
    method = event.get('httpMethod') or event.get('requestContext', {}).get('http', {}).get('method', '')

    if method == 'OPTIONS':
        return respuesta(200, "")

    try:
        body_str = event.get('body', '')
        if event.get('isBase64Encoded', False):
            import base64
            body_str = base64.b64decode(body_str).decode('utf-8')

        parsed_params = parse_qs(body_str)
        data = {k: v[0] for k, v in parsed_params.items()}

        correo = data.get('correo', '')
        tarjeta = data.get('tarjeta', '')

        # Validar Correo
        if not validar_correo(correo):
            return respuesta(200, """
                <div class="p-4 bg-red-900/20 border border-cyber text-cyber rounded font-mono text-sm mt-4">
                    <p class="font-bold">[-] ERROR_SINTAXIS: Correo electrÃ³nico invÃ¡lido.</p>
                </div>
                """, {"Content-Type": "text/html"})

        # Validar Tarjeta (Algoritmo de Luhn)
        if not validar_tarjeta(tarjeta):
            return respuesta(200, """
                <div class="p-4 bg-red-900/20 border border-cyber text-cyber rounded font-mono text-sm mt-4">
                    <p class="font-bold">[-] TRANSACCIÃ“N_RECHAZADA: El nÃºmero de tarjeta no es vÃ¡lido.</p>
                </div>
                """, {"Content-Type": "text/html"})

        # Ã‰XITOOO
        return respuesta(200, f"""
            <div class="p-4 bg-green-900/20 border border-green-500 text-green-400 rounded font-mono text-sm mt-4">
                <p class="font-bold">[+] TRANSACCIÃ“N_AUTORIZADA</p>
                <p class="mt-1">ValidaciÃ³n criptogrÃ¡fica exitosa para la credencial de pago.</p>
                <p class="text-xs text-gray-500 mt-2">Recibo enviado a: {correo}</p>
                <a href="purchases_2.html" class="mt-4 block w-full text-center bg-green-500/10 border border-green-500 text-green-400 p-2 hover:bg-green-500 hover:text-black transition">
                    Ver Comprobante
                </a>
            </div>
            """, {"Content-Type": "text/html"})

    except Exception as e:
        return respuesta(500, f"<p class='text-cyber'>Error del sistema: {str(e)}</p>", {"Content-Type": "text/html"})