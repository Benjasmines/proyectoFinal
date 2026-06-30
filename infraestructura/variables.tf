variable "region" {
  type        = string
  description = "Región AWS donde serán desplegados los recursos"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Nombre del proyecto para mejor identificación en tags"
  default     = "ehacking-service"
}

variable "environment" {
  type        = string
  description = "Entorno de despliegue"
  default     = "dev"
}

variable "vpc_cidr" {
  type        = string
  description = "Bloque CIDR de la VPC"
  default     = "10.0.0.0/16"
}

variable "subnet_cidr_1" {
  type        = string
  description = "CIDR de la subred pública en AZ-a"
  default     = "10.0.1.0/24"
}

variable "subnet_cidr_2" {
  type        = string
  description = "CIDR de la subred pública en AZ-b"
  default     = "10.0.2.0/24"
}

variable "subnet_cidr_3" {
  type        = string
  description = "CIDR de la subred privada en AZ-a"
  default     = "10.0.3.0/24"
}

variable "subnet_cidr_4" {
  type        = string
  description = "CIDR de la subred privada en AZ-b"
  default     = "10.0.4.0/24"
}

variable "container_cpu" {
  type        = string
  description = "Unidades de CPU para la tarea ECS"
  default     = "256"
}

variable "container_memory" {
  type        = string
  description = "Memoria en MB para la tarea ECS"
  default     = "512"
}

variable "desired_count" {
  type        = number
  description = "Número deseado de tareas Fargate en ejecución"
  default     = 4
}

variable "image_tag" {
  type        = string
  description = "Tag de la imagen Docker que se construirá y publicará"
  default     = "1.0"
}

variable "app_path" {
  type        = string
  description = "Ruta local al directorio con el Dockerfile"
  default     = "../sitio-web"
}