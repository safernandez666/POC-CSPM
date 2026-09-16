output "vpc_id" {
  description = "ID de la VPC vulnerable"
  value       = aws_vpc.vulnerable_vpc.id
}

output "subnet_id" {
  description = "ID de la subnet pública"
  value       = aws_subnet.public_subnet.id
}

output "s3_bucket_name" {
  description = "Nombre del S3 bucket vulnerable"
  value       = aws_s3_bucket.vulnerable_bucket.id
}

output "s3_bucket_arn" {
  description = "ARN del S3 bucket vulnerable"
  value       = aws_s3_bucket.vulnerable_bucket.arn
}

output "s3_bucket_url" {
  description = "URL pública del S3 bucket"
  value       = "http://${aws_s3_bucket.vulnerable_bucket.bucket}.s3.amazonaws.com/sample-data.txt"
}

output "ec2_instance_id" {
  description = "ID de la instancia EC2 vulnerable"
  value       = aws_instance.vulnerable_instance.id
}

output "ec2_public_ip" {
  description = "IP pública de la instancia EC2"
  value       = aws_instance.vulnerable_instance.public_ip
}

output "ec2_public_dns" {
  description = "DNS público de la instancia EC2"
  value       = aws_instance.vulnerable_instance.public_dns
}

output "security_group_id" {
  description = "ID del Security Group vulnerable"
  value       = aws_security_group.vulnerable_sg.id
}

output "iam_role_name" {
  description = "Nombre del IAM role vulnerable"
  value       = aws_iam_role.vulnerable_ec2_role.name
}

output "iam_role_arn" {
  description = "ARN del IAM role vulnerable"
  value       = aws_iam_role.vulnerable_ec2_role.arn
}

output "instance_web_url" {
  description = "URL para acceder a la instancia EC2 vía HTTP"
  value       = "http://${aws_instance.vulnerable_instance.public_ip}"
}

output "security_issues_summary" {
  description = "Resumen de problemas de seguridad intencionados"
  value = <<-EOT
  
  ⚠️  PROBLEMAS DE SEGURIDAD DETECTADOS (Intencionados):
  
  📦 S3 Bucket:
    - Acceso público habilitado
    - Sin encriptación
    - Sin versionado
    - Sin logging
    - Archivo público: ${aws_s3_bucket.vulnerable_bucket.bucket}/sample-data.txt
  
  🔒 Security Group:
    - SSH (22) abierto a 0.0.0.0/0
    - HTTP (80) abierto a 0.0.0.0/0
    - RDP (3389) abierto a 0.0.0.0/0
  
  👤 IAM:
    - Permisos S3FullAccess
    - Permisos EC2FullAccess
    - Sin MFA requirements
  
  💻 EC2:
    - IMDSv1 habilitado (inseguro)
    - Sin monitoring detallado
    - EBS sin encriptación
    - Secrets hardcodeados en user data
  
  🌐 VPC:
    - Sin Flow Logs habilitados
  
  📊 CloudTrail:
    - NO configurado
  
  Para escanear: prowler aws --region ${var.aws_region}
  EOT
}
