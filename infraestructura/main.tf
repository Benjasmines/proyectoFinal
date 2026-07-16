# ============================================================
# DATA SOURCES
# ============================================================
data "aws_caller_identity" "current" {}

# ECR — REPOSITORIO DE IMÁGENES DOCKER
# ============================================================
resource "aws_ecr_repository" "app" {
  name                 = var.project_name
  force_delete         = true
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = var.project_name }
}


# ============================================================
# VPC Y RED MULTI-AZ (USANDO MÓDULO OFICIAL)
# ============================================================
module "vpc" {
    source  = "terraform-aws-modules/vpc/aws"
    version = "5.5.0"
    name = var.project_name
    cidr = var.vpc_cidr

    azs             = ["${var.region}a", "${var.region}b"]
    public_subnets  = [var.subnet_cidr_1, var.subnet_cidr_2]
    private_subnets = [var.subnet_cidr_3, var.subnet_cidr_4]

    enable_nat_gateway   = true
    single_nat_gateway   = true # Un solo NAT para ambas subredes (ahorra costos)
    enable_dns_hostnames = true
    enable_dns_support   = true

    tags = {
        Environment = var.environment
    }
}

# ============================================================
# SECURITY GROUP
# ============================================================
# SG del ALB — acepta HTTP desde internet
resource "aws_security_group" "alb" {
    name        = "${var.project_name}-alb-sg"
    description = "Permite HTTP entrante desde internet al ALB"
    vpc_id      = module.vpc.vpc_id 

    ingress {
        description = "HTTP desde internet"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        description = "Todo el trafico saliente"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = { Name = "${var.project_name}-alb-sg" }
}

# SG de ECS — solo acepta tráfico proveniente del ALB
resource "aws_security_group" "ecs" {
    name        = "${var.project_name}-ecs-sg"
    description = "Permite trafico al contenedor solo desde el ALB"
    vpc_id      = module.vpc.vpc_id 

    ingress {
        description     = "HTTP desde el ALB"
        from_port       = 80
        to_port         = 80
        protocol        = "tcp"
        security_groups = [aws_security_group.alb.id]
    }

    egress {
        description = "Todo el trafico saliente (necesario para ECR, etc.)"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = { Name = "${var.project_name}-ecs-sg" }
}

# ============================================================
# APPLICATION LOAD BALANCER (ALB)
# ============================================================
resource "aws_lb" "main" {
    name               = "${var.project_name}-alb"
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.alb.id]
    subnets            = module.vpc.public_subnets 

    tags = { Name = "${var.project_name}-alb" }
}

resource "aws_lb_target_group" "main" {
    name        = "${var.project_name}-tg"
    port        = 80
    protocol    = "HTTP"
    vpc_id      = module.vpc.vpc_id 
    target_type = "ip"

    health_check {
        path                = "/"
        healthy_threshold   = 2
        unhealthy_threshold = 3
        interval            = 30
    }

    tags = { Name = "${var.project_name}-tg" }
}

resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.main.arn
    port              = 80
    protocol          = "HTTP"

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.main.arn
    }
}

# ============================================================
# IAM — ROL DE EJECUCIÓN DE TAREAS ECS
# ============================================================
resource "aws_iam_role" "ecs_task_execution" {
    name = "${var.project_name}-ecsTaskExecutionRole"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action    = "sts:AssumeRole"
            Effect    = "Allow"
            Principal = { Service = "ecs-tasks.amazonaws.com" }
        }]
    })

    tags = { Name = "${var.project_name}-ecs-task-execution" }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
    role       = aws_iam_role.ecs_task_execution.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ============================================================
# ECS — CLÚSTER, TASK DEFINITION Y SERVICIO FARGATE
# ============================================================
resource "aws_ecs_cluster" "main" {
    name = "${var.project_name}-cluster"
    tags = { Name = "${var.project_name}-cluster" }
}

resource "aws_ecs_task_definition" "app" {
    family                   = "${var.project_name}-task"
    network_mode             = "awsvpc"
    requires_compatibilities = ["FARGATE"]
    cpu                      = var.container_cpu
    memory                   = var.container_memory
    execution_role_arn       = aws_iam_role.ecs_task_execution.arn

    container_definitions = jsonencode([{
        name  = "web"
        image = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
        portMappings = [{
            containerPort = 80
            hostPort      = 80
            protocol      = "tcp"
        }]
        essential = true
    }])

    tags = { Name = "${var.project_name}-task" }
}

resource "aws_ecs_service" "app" {
    name            = "${var.project_name}-svc"
    cluster         = aws_ecs_cluster.main.id
    task_definition = aws_ecs_task_definition.app.arn
    desired_count   = var.desired_count
    launch_type     = "FARGATE"

    network_configuration {
        subnets          = module.vpc.private_subnets
        security_groups  = [aws_security_group.ecs.id]
        assign_public_ip = false
    }

    load_balancer {
        target_group_arn = aws_lb_target_group.main.arn
        container_name   = "web"
        container_port   = 80
    }

    depends_on = [
        aws_lb_listener.http,
        aws_iam_role_policy_attachment.ecs_task_execution
    ]

    tags = { Name = "${var.project_name}-svc" }
}

resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 8
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_cpu_policy" {
  name               = "${var.project_name}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 75.0 # Agrega más contenedores si el CPU supera el 75%
  }
}

# 1. Bucket S3 para guardar los datos de contacto
resource "aws_s3_bucket" "contact_data" {
  bucket = "${var.project_name}-contactos-${data.aws_caller_identity.current.account_id}"
}

# 2. Rol IAM para la Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "lambda_s3_policy" {
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["s3:PutObject"],
      Effect   = "Allow",
      Resource = "${aws_s3_bucket.contact_data.arn}/*"
    }]
  })
}

# ============================================================
# 3. LAMBDA — FORMULARIO DE CONTACTO 
# ============================================================
# Empaquetamos el código de contacto en tiempo real
data "archive_file" "zip_contacto" {
  type        = "zip"
  source_file = "${path.module}/backend/contacto.py" 
  output_path = "${path.module}/backend/lambda_contacto.zip"
}

resource "aws_lambda_function" "contact_handler" {
  function_name    = "${var.project_name}-contacto"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "contacto.lambda_handler"
  runtime          = "python3.9"

  # Usamos el zip dinámico
  filename         = data.archive_file.zip_contacto.output_path
  source_code_hash = data.archive_file.zip_contacto.output_base64sha256

  environment {
    variables = { BUCKET_NAME = aws_s3_bucket.contact_data.bucket }
  }
}

# ============================================================
# 4. API GATEWAY 
# ============================================================
resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "GET", "OPTIONS"]
    allow_headers = ["content-type", "authorization"] 
    max_age       = 300                               
  }
}

# -> Ruta 1: POST /contacto
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.contact_handler.invoke_arn
}

resource "aws_apigatewayv2_route" "post_contacto" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /contacto"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "api_gw" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# ============================================================
# 5. LAMBDA Y API GATEWAY — AMENAZAS EN TIEMPO REAL
# ============================================================
# -> Empaquetamos el código de amenazas
data "archive_file" "zip_amenazas" {
  type        = "zip"
  source_file = "${path.module}/backend/lambda_amenazas.py"
  output_path = "${path.module}/backend/lambda_amenazas.zip"
}

# -> Rol básico para la Lambda de Amenazas
resource "aws_iam_role" "rol_para_lambda" {
  name = "${var.project_name}-rol-amenazas"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "permisos_basicos_lambda" {
  role       = aws_iam_role.rol_para_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# -> Función Lambda de Amenazas
resource "aws_lambda_function" "lambda_amenazas" {
  function_name = "${var.project_name}-api-amenazas"
  
  filename         = data.archive_file.zip_amenazas.output_path
  source_code_hash = data.archive_file.zip_amenazas.output_base64sha256

  handler = "lambda_amenazas.lambda_handler" 
  runtime = "python3.10" 
  timeout = 10 
  role    = aws_iam_role.rol_para_lambda.arn 
}

# -> Ruta 2: GET /amenazas
resource "aws_apigatewayv2_integration" "integracion_amenazas" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.lambda_amenazas.invoke_arn
}

resource "aws_apigatewayv2_route" "ruta_amenazas" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /amenazas"
  target    = "integrations/${aws_apigatewayv2_integration.integracion_amenazas.id}"
}

resource "aws_lambda_permission" "permiso_api_gateway_amenazas" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_amenazas.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "local_file" "api_config" {
    filename = "${path.module}/../sitio-web/config.json" 
    content  = jsonencode({
        apiUrl = "${aws_apigatewayv2_api.http_api.api_endpoint}"
    })
}

# ============================================================
# PERMISOS DE S3 PARA EL FORMULARIO DE CONTACTO
# ============================================================
resource "aws_iam_role_policy" "lambda_s3_contacto_nuevo" {
  name = "${var.project_name}-s3-contacto-policy"
  
  # Extraemos el nombre del rol directamente del de contacto
  role = split("/", aws_lambda_function.contact_handler.role)[1]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]

        Resource = "arn:aws:s3:::${var.project_name}-contactos-bucket/*" 
      }
    ]
  })
}