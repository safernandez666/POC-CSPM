# Infraestructura AWS Vulnerable - CSPM Demo

Terraform configuration para crear infraestructura AWS **intencionalmente insegura** con propósitos educativos.

⚠️ **ADVERTENCIA:** Esta infraestructura contiene 15+ vulnerabilidades de seguridad. Solo usar en entornos de testing.

## 🎯 Vulnerabilidades Implementadas

### 🔴 Severidad Alta (4 problemas)

1. **S3 Bucket Público** - ACL `public-read`
2. **S3 Sin Encriptación** - Datos en reposo sin protección
3. **Security Group SSH Abierto** - Puerto 22 expuesto a 0.0.0.0/0
4. **Security Group RDP Abierto** - Puerto 3389 expuesto a 0.0.0.0/0

### 🟡 Severidad Media (5 problemas)

5. **IAM Permisos Excesivos** - S3FullAccess + EC2FullAccess
6. **EC2 IMDSv1 Habilitado** - Vulnerable a ataques SSRF
7. **VPC Sin Flow Logs** - Sin visibilidad de tráfico
8. **EBS Sin Encriptación** - Volúmenes sin cifrado
9. **S3 Sin Versionado** - Sin protección contra eliminación accidental

### 🔵 Severidad Baja (6 problemas)

10. **CloudTrail No Configurado** - Sin auditoría de API calls
11. **S3 Sin Logging** - Sin registros de acceso
12. **Secrets Hardcodeados** - Credenciales en user_data
13. **EC2 Sin Monitoring** - Monitoring detallado deshabilitado
14. **Security Group HTTP Abierto** - Puerto 80 expuesto
15. **VPC Sin Network ACLs** - Solo Security Groups

## 🏗️ Recursos Creados

| Recurso | Descripción | Tag |
|---------|-------------|-----|
| VPC | 10.0.0.0/16 | `Project=cspm-demo` |
| Subnet | 10.0.1.0/24 (pública) | `Project=cspm-demo` |
| Internet Gateway | Conectividad pública | `Project=cspm-demo` |
| Security Group | SSH/HTTP/RDP abierto | `Project=cspm-demo` |
| EC2 t2.micro | Amazon Linux 2 | `Project=cspm-demo` |
| S3 Bucket | Público sin encriptación | `Project=cspm-demo` |
| IAM Role | Permisos excesivos | `Project=cspm-demo` |

**Todos los recursos tienen el tag `Project=cspm-demo`** para filtrado con Prowler.

## 🚀 Uso

### Prerequisitos

- AWS CLI configurado
- Terraform >= 1.0
- Credenciales AWS con permisos de administrador
- Región: us-east-1 (configurable en variables.tf)

### Deployment

```bash
# 1. Inicializar Terraform
terraform init

# 2. Ver plan de ejecución
terraform plan

# 3. Desplegar infraestructura
terraform apply

# 4. Ver outputs importantes
terraform output
```

### Outputs Importantes

Después del `terraform apply`, verás:

```
ec2_instance_id      = "i-xxxxx"
ec2_public_ip        = "54.xxx.xxx.xxx"
s3_bucket_name       = "cspm-demo-vulnerable-bucket-xxxxx"
security_group_id    = "sg-xxxxx"
vpc_id               = "vpc-xxxxx"
```

## 🔍 Escaneo con Prowler

Una vez desplegada la infraestructura, escanea con Prowler:

```bash
# Opción 1: Docker (recomendado)
docker run --rm \
  -e AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY \
  -v $(pwd)/../../prowler-output:/prowler/output \
  public.ecr.aws/prowler-cloud/prowler:stable aws \
  --resource-tag Project=cspm-demo \
  --output-formats html csv json-ocsf \
  --output-directory /prowler/output

# Opción 2: Prowler local (si lo tienes instalado)
prowler aws \
  --resource-tag Project=cspm-demo \
  --output-formats html csv json-ocsf
```

**Importante:** El flag `--resource-tag Project=cspm-demo` filtra el escaneo SOLO a los recursos de esta demo.

## 🧹 Cleanup

**⚠️ MUY IMPORTANTE:** Destruir la infraestructura cuando termines para evitar:
- Costos continuos (~$8-10/mes)
- Exposición de seguridad

```bash
# Destruir toda la infraestructura
terraform destroy

# Confirmar con 'yes' cuando se solicite
```

## 📁 Estructura de Archivos

```
terraform/
├── main.tf              # Configuración principal (320+ líneas)
├── variables.tf         # Variables configurables
├── outputs.tf           # Outputs importantes
├── terraform.tfvars     # Valores de variables
└── README.md           # Este archivo
```

## ⚙️ Variables Configurables

Edita `terraform.tfvars` para personalizar:

```hcl
aws_region    = "us-east-1"    # Región AWS
project_name  = "cspm-demo"    # Nombre del proyecto
instance_type = "t2.micro"     # Tipo de instancia EC2
```

## 📊 Resultados Esperados de Prowler

Cuando escaneas esta infraestructura con Prowler, deberías ver:

- **Total checks:** 75
- **Failed:** ~23 (46%)
- **Passed:** ~27 (54%)

**Desglose:**
- EC2: 9 fallas (2 críticas, 4 altas)
- S3: 14 fallas (2 críticas, 2 altas)

## 🛡️ Remediación (Parte 4 de la serie)

Para remediar estas vulnerabilidades, ver **Parte 4** de la serie donde usamos **Cloud Custodian**.

## ⚠️ Seguridad

**NO USAR EN PRODUCCIÓN**

- Esta infraestructura es intencionalmente insegura
- Solo para propósitos educativos
- Usar en cuenta AWS dedicada para testing
- Destruir después de las pruebas
- No exponer datos sensibles reales

## 💰 Estimación de Costos

| Recurso | Costo 24/7 | Free Tier |
|---------|-----------|-----------|
| EC2 t2.micro | $8.50/mes | 750 hrs/mes gratis |
| S3 Storage | $0.023/GB | 5 GB gratis |
| Data Transfer | Variable | 1 GB gratis |
| VPC/Networking | $0 | Gratis |

**Total estimado:** $8-10/mes (Free tier: $0 los primeros 12 meses)

## 🔗 Referencias

- [Prowler Documentation](https://docs.prowler.com/)
- [CIS AWS Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)
- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## 📝 Licencia

MIT License

---

**Parte de la serie:** [CSPM Sin Pagar Licencias](../../README.md)
