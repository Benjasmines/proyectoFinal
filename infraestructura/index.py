import json, boto3, uuid, datetime, os
from urllib.parse import parse_qs

s3 = boto3.client('s3')
BUCKET_NAME = os.environ['BUCKET_NAME']

def lambda_handler(event, context):
    datos = parse_qs(event['body'])
    contacto = {
        "id": str(uuid.uuid4()),
        "nombre": datos.get('nombre', [''])[0],
        "mensaje": datos.get('mensaje', [''])[0],
        "fecha": str(datetime.datetime.now())
    }
    s3.put_object(
        Bucket=BUCKET_NAME,
        Key=f"contacto_{contacto['id']}.json",
        Body=json.dumps(contacto)
    )
    return {
        'statusCode': 200,
        'headers': {'Access-Control-Allow-Origin': '*'},
        'body': 'Mensaje enviado correctamente'
    }