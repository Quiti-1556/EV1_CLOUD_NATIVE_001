variable "project" {
  type    = string
  default = "solicitud"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,15}$", var.project))
    error_message = "project: 3-16 caracteres, minúsculas, números y guiones."
  }
}
variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "environment debe ser dev, qa o prod."
  }
}
variable "aws_region" {
  type = string
}
variable "vpc_cidr" {
  type = string
}
variable "frontend_branch" {
  type = string
}
variable "local_development" {
  type = bool
}
variable "multi_az" {
  type = bool
}
variable "deletion_protection" {
  type = bool
}
variable "db_instance_class" {
  type = string
}
variable "task_count" {
  type = number
  validation {
    condition     = var.task_count >= 1 && var.task_count <= 10 && floor(var.task_count) == var.task_count
    error_message = "task_count debe ser un entero entre 1 y 10."
  }
}
variable "existing_execution_role_arn" {
  type        = string
  default     = ""
  description = "Opcional: rol de ejecución existente (por ejemplo LabRole). Debe leer el secreto RDS, ECR y escribir logs."
}
variable "existing_task_role_arn" {
  type        = string
  default     = ""
  description = "Opcional: rol existente para la aplicación. En cuenta normal se crea uno sin permisos AWS."
}
variable "existing_lambda_role_arn" {
  type        = string
  default     = ""
  description = "Opcional: rol existente para user-token-ms; en Learner Lab puede ser LabRole si Lambda puede asumirlo."
}
