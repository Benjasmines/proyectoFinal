# ============================================================
# DATA SOURCES
# ============================================================
data "aws_caller_identity" "current" {}

# ============================================================
# ECR — REPOSITORIO DE IMÁGENES DOCKER
# ============================================================
resource "aws_ecr_repository" "app" {
    name         = var.project_name
    force_delete = true

    tags         = { Name = var.project_name }
}

resource "null_resource" "docker_build_push" {
    depends_on   = [aws_ecr_repository.app]

    triggers     = {
        repo_url  = aws_ecr_repository.app.repository_url
        image_tag = var.image_tag
    }

    provisioner "local-exec" {
        command  = <<-EOT
            aws ecr get-login-password --region ${var.region} |  docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com && docker build --no-cache -t ${var.project_name}:${var.image_tag} ${var.app_path} && docker tag ${var.project_name}:${var.image_tag} ${aws_ecr_repository.app.repository_url}:${var.image_tag} && docker push ${aws_ecr_repository.app.repository_url}:${var.image_tag}
        EOT
    }
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
    depends_on               = [null_resource.docker_build_push]
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