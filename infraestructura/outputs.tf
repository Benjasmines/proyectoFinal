output "alb_url" {
  description = "URL pública del Application Load Balancer"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecr_repository_url" {
  description = "URL del repositorio ECR"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "Nombre del clúster ECS"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Nombre del servicio ECS"
  value       = aws_ecs_service.app.name
}

output "vpc_id" {
  description = "ID de la VPC creada"
  value       = module.vpc.vpc_id
}

output "subnet_ids" {
  description = "IDs de las subredes públicas (ALB)"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs de las subredes privadas (ECS Fargate)"
  value       = module.vpc.private_subnets
}

output "nat_gateway_ip" {
  description = "IP pública del NAT Gateway"
  value       = module.vpc.nat_public_ips[0]
}