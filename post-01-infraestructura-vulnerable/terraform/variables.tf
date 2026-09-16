variable "aws_region" {
  description = "AWS region donde se desplegará la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto (usado para naming)"
  type        = string
  default     = "cspm-demo"
}

variable "instance_type" {
  description = "Tipo de instancia EC2 (t2.micro para free tier)"
  type        = string
  default     = "t2.micro"
}
