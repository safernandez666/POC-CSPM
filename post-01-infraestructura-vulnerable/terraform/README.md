# Infraestructura vulnerable (módulo Terraform)

Este módulo crea, a propósito, una infra chica e insegura en AWS para tener algo real que escanear con Prowler y remediar con Cloud Custodian. No es para producción — ver advertencias en el [README principal](../../README.md).

Todos los recursos llevan el tag `Project=cspm-demo`.

## Recursos que crea

| Recurso | Detalle |
|---|---|
| VPC + Subnet pública | `10.0.0.0/16` |
| Security Group | SSH (22), HTTP (80) y RDP (3389) abiertos a `0.0.0.0/0` |
| EC2 t2.micro | Amazon Linux 2, IMDSv1 habilitado, EBS sin encriptar, secrets en user_data |
| S3 Bucket | Público, sin encriptación, sin versionado, sin logging |
| IAM Role | `AmazonS3FullAccess` + `AmazonEC2FullAccess` |

## Vulnerabilidades intencionales

**Altas:** S3 público, S3 sin encriptación, SSH abierto, RDP abierto.

**Medias:** IAM con permisos excesivos, IMDSv1, VPC sin Flow Logs, EBS sin encriptar, S3 sin versionado.

**Bajas:** CloudTrail no configurado, S3 sin logging, secrets hardcodeados en user_data, EC2 sin monitoring detallado, HTTP abierto, sin Network ACLs.

## Variables

Editables en `terraform.tfvars` (copiá `terraform.tfvars.example`):

```hcl
aws_region    = "us-east-1"
project_name  = "cspm-demo"
instance_type = "t2.micro"  # Free tier elegible
```

## Uso

Este módulo no se corre a mano — lo maneja `run-cspm.sh` (ver README principal, opciones 1/2/5 del menú). Si igual querés correrlo directo:

```bash
cd post-01-infraestructura-vulnerable/terraform
terraform init
terraform apply
# ...
terraform destroy
```
