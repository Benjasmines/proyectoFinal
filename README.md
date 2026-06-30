# proyectoFinal

Max Coñoman y Benjamin Uribe

Para esta primera parte del proyecto con terraform solo se crea un bucket y se enlaza a un s3 por lo que el codigo a futuro se modificará más y se podrá tener mas esstructura a su vez para poder hacerlo funcionar es necesario tener terraform instalado y estar en la carpeta del proyecto y seguir el flujo de vida de terraform (init, plan, apply, destroy).

# Despliegue

Inicializar Terraform:

```bash
terraform init
```

Validar la configuración:

```bash
terraform validate
```

Visualizar el plan de ejecución:

```bash
terraform plan
```

Crear la infraestructura:

```bash
terraform apply
```

Eliminar la infraestructura:

```bash
terraform destroy
```

# Requisitos

- Terraform 1.2 o superior
- Cuenta de AWS
- AWS CLI configurado
- Credenciales válidas con permisos para crear recursos
