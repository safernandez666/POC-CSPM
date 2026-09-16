terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source para obtener la AMI más reciente de Amazon Linux 2
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ============================================
# VPC - Sin Flow Logs (Problema de Seguridad)
# ============================================
resource "aws_vpc" "vulnerable_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = "vulnerable"
    Purpose     = "cspm-demo"
  }
}

# Subnet pública
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.vulnerable_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true # Problema: IPs públicas automáticas

  tags = {
    Name        = "${var.project_name}-public-subnet"
    Project     = "cspm-demo"
    Environment = "vulnerable"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vulnerable_vpc.id

  tags = {
    Name        = "${var.project_name}-igw"
    Project     = "cspm-demo"
    Environment = "vulnerable"
  }
}

# Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vulnerable_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Project     = "cspm-demo"
    Environment = "vulnerable"
  }
}

# Route Table Association
resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Data source para AZs disponibles
data "aws_availability_zones" "available" {
  state = "available"
}

# ============================================
# S3 Bucket - Múltiples Problemas de Seguridad
# ============================================
resource "aws_s3_bucket" "vulnerable_bucket" {
  bucket = "${var.project_name}-vulnerable-bucket-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "${var.project_name}-vulnerable-bucket"
    Project     = "cspm-demo"
    Environment = "vulnerable"
    Purpose     = "cspm-demo"
  }

  # Problema: Sin force_destroy en producción, pero aquí lo necesitamos para testing
  force_destroy = true
}

# Random ID para nombre único de bucket
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Problema: Public Access Block DESHABILITADO
resource "aws_s3_bucket_public_access_block" "vulnerable_bucket_pab" {
  bucket = aws_s3_bucket.vulnerable_bucket.id

  block_public_acls       = false # Problema: Debería ser true
  block_public_policy     = false # Problema: Debería ser true
  ignore_public_acls      = false # Problema: Debería ser true
  restrict_public_buckets = false # Problema: Debería ser true
}

# Habilitar ACLs en el bucket (requerido desde 2023)
resource "aws_s3_bucket_ownership_controls" "vulnerable_bucket_ownership" {
  bucket = aws_s3_bucket.vulnerable_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Problema: Bucket público con ACL
resource "aws_s3_bucket_acl" "vulnerable_bucket_acl" {
  depends_on = [
    aws_s3_bucket_public_access_block.vulnerable_bucket_pab,
    aws_s3_bucket_ownership_controls.vulnerable_bucket_ownership
  ]
  bucket = aws_s3_bucket.vulnerable_bucket.id
  acl    = "public-read" # Problema: Bucket público
}

# Problema: Sin encriptación
# Intencionalmente NO configuramos aws_s3_bucket_server_side_encryption_configuration

# Problema: Sin versionado
# Intencionalmente NO configuramos aws_s3_bucket_versioning

# Problema: Sin logging
# Intencionalmente NO configuramos aws_s3_bucket_logging

# Subir un archivo de ejemplo al bucket
resource "aws_s3_object" "sample_file" {
  depends_on = [
    aws_s3_bucket_ownership_controls.vulnerable_bucket_ownership
  ]
  bucket       = aws_s3_bucket.vulnerable_bucket.id
  key          = "sample-data.txt"
  content      = "This is a sample file in a vulnerable S3 bucket for CSPM demo purposes."
  content_type = "text/plain"
  acl          = "public-read" # Problema: Archivo público
}

# ============================================
# Security Group - MUY Permisivo
# ============================================
resource "aws_security_group" "vulnerable_sg" {
  name        = "${var.project_name}-vulnerable-sg"
  description = "Intentionally insecure security group for CSPM demo"
  vpc_id      = aws_vpc.vulnerable_vpc.id

  # Problema: SSH abierto al mundo
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Problema: Debería ser restringido
    description = "SSH from anywhere"
  }

  # Problema: HTTP abierto al mundo
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere"
  }

  # Problema: RDP abierto al mundo
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Problema: RDP público
    description = "RDP from anywhere"
  }

  # Problema: Todo el tráfico saliente permitido
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name        = "${var.project_name}-vulnerable-sg"
    Project     = "cspm-demo"
    Environment = "vulnerable"
  }
}

# ============================================
# IAM Role - Permisos Excesivos
# ============================================
resource "aws_iam_role" "vulnerable_ec2_role" {
  name = "${var.project_name}-vulnerable-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-vulnerable-role"
    Project     = "cspm-demo"
    Environment = "vulnerable"
  }
}

# Problema: Políticas demasiado amplias
resource "aws_iam_role_policy_attachment" "s3_full_access" {
  role       = aws_iam_role.vulnerable_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess" # Problema: Full access
}

resource "aws_iam_role_policy_attachment" "ec2_full_access" {
  role       = aws_iam_role.vulnerable_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess" # Problema: Full access
}

# Instance Profile
resource "aws_iam_instance_profile" "vulnerable_profile" {
  name = "${var.project_name}-vulnerable-profile"
  role = aws_iam_role.vulnerable_ec2_role.name
}

# ============================================
# EC2 Instance - Múltiples Problemas
# ============================================
resource "aws_instance" "vulnerable_instance" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.vulnerable_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.vulnerable_profile.name

  # Problema: IMDSv1 habilitado (inseguro)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional" # Problema: Debería ser "required" para IMDSv2
    http_put_response_hop_limit = 1
  }

  # Problema: Sin monitoring detallado
  monitoring = false # Problema: Debería ser true

  # Problema: EBS sin encriptación
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = false # Problema: Debería estar encriptado
    delete_on_termination = true
  }

  # Problema: User data con secrets hardcodeados
  user_data = <<-EOF
              #!/bin/bash
              # Problema: Secrets en plain text
              export DB_PASSWORD="SuperSecretPassword123!"
              export API_KEY="sk-1234567890abcdef"
              
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              
              echo "<h1>Vulnerable Instance - CSPM Demo</h1>" > /var/www/html/index.html
              echo "<p>This instance has multiple security issues:</p>" >> /var/www/html/index.html
              echo "<ul>" >> /var/www/html/index.html
              echo "<li>Public access via 0.0.0.0/0</li>" >> /var/www/html/index.html
              echo "<li>IMDSv1 enabled</li>" >> /var/www/html/index.html
              echo "<li>Unencrypted EBS</li>" >> /var/www/html/index.html
              echo "<li>No detailed monitoring</li>" >> /var/www/html/index.html
              echo "<li>Hardcoded secrets in user data</li>" >> /var/www/html/index.html
              echo "</ul>" >> /var/www/html/index.html
              EOF

  tags = {
    Name        = "${var.project_name}-vulnerable-instance"
    Project     = "cspm-demo"
    Environment = "vulnerable"
    Purpose     = "cspm-demo"
    # Problema: Sin tags de compliance o owner
  }

  # Problema: Sin protection de terminación
  disable_api_termination = false
}

# ============================================
# CloudWatch - Sin Logs (Problema)
# ============================================
# Intencionalmente NO configuramos CloudWatch Logs para VPC Flow Logs

# ============================================
# CloudTrail - NO Configurado (Problema)
# ============================================
# Intencionalmente NO configuramos CloudTrail
