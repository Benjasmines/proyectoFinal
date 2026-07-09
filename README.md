# ByteKnight - Infraestructura como Código (IaC)

## Arquitectura Desplegada

Este proyecto despliega una infraestructura segura y altamente disponible en AWS utilizando Terraform:

- **Red:** VPC con subredes públicas y privadas distribuidas en múltiples Zonas de Disponibilidad (Multi-AZ).
- **Cómputo:** Clúster ECS con contenedores Fargate (Serverless) gestionados por Auto Scaling.
- **Balanceo de Carga:** Application Load Balancer (ALB) expuesto a internet.
- **Backend Serverless:** API Gateway + Lambda + S3 para procesar y almacenar los contactos del frontend mediante HTMX de forma segura.

## Instrucciones de Despliegue

Para desplegar esta infraestructura, asegúrate de tener configurado AWS CLI y Docker iniciado en tu máquina local.

1. Inicializar Terraform: `terraform init`
2. Revisar el plan: `terraform plan`
3. Aplicar los cambios: `terraform apply -auto-approve`

## Gestión de Costos y Limpieza

Para optimizar costos durante el MVP, se ha implementado un único NAT Gateway en lugar de uno por cada Zona de Disponibilidad.
**IMPORTANTE:** Para no generar cargos innecesarios en la cuenta de AWS tras la evaluación, es obligatorio destruir la infraestructura ejecutando:
`terraform destroy -auto-approve`
