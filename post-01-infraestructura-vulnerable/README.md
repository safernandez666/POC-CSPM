# Post 1: Infraestructura Vulnerable en AWS

## 🎯 Objetivo

Crear una infraestructura AWS con **problemas de seguridad comunes** para luego detectarlos con Prowler y remediarlos con Cloud Custodian.

## 🏗️ Recursos Creados

### 1. VPC y Networking
- VPC sin Flow Logs
- Subnet pública sin encriptación de tráfico

### 2. S3 Bucket (Múltiples problemas)
- ❌ Acceso público habilitado
- ❌ Sin encriptación
- ❌ Sin versionado
- ❌ Sin logging de acceso
- ❌ Sin bloqueo de ACLs públicas
- ❌ Sin MFA Delete

### 3. Security Group
- ❌ SSH (22) abierto a 0.0.0.0/0
- ❌ HTTP (80) abierto a 0.0.0.0/0
- ❌ RDP (3389) abierto a 0.0.0.0/0
- ❌ Sin descripción detallada

### 4. IAM Role
- ❌ Permisos muy amplios (S3FullAccess, EC2FullAccess)
- ❌ Sin restricciones de MFA
- ❌ Sin condiciones de IP o tiempo

### 5. EC2 Instance (t2.micro - Free Tier)
- ❌ Sin monitoring detallado
- ❌ IMDSv1 habilitado (inseguro)
- ❌ Sin encriptación de EBS
- ❌ Sin tagging apropiado
- ❌ User data con secrets hardcodeados

## 🔍 Problemas de Seguridad Incluidos

| Categoría | Problema | Severidad |
|-----------|----------|-----------|
| **S3** | Bucket público | 🔴 Alta |
| **S3** | Sin encriptación | 🔴 Alta |
| **EC2** | Security Group muy permisivo | 🔴 Alta |
| **IAM** | Permisos excesivos | 🟡 Media |
| **EC2** | IMDSv1 habilitado | 🟡 Media |
| **VPC** | Sin Flow Logs | 🟡 Media |
| **EC2** | Sin monitoring | 🟢 Baja |
| **S3** | Sin versionado | 🟢 Baja |

## 💰 Costos

- **EC2 t2.micro**: Elegible para Free Tier (750 horas/mes)
- **S3**: Prácticamente gratis con poco uso
- **Otros**: Gratis

**Total estimado: $0-8/mes**

## 🚀 Despliegue

```bash
cd terraform

# Copiar variables de ejemplo
cp terraform.tfvars.example terraform.tfvars

# Editar con tu región preferida
nano terraform.tfvars

# Inicializar Terraform
terraform init

# Ver plan de ejecución
terraform plan

# Aplicar cambios
terraform apply
```

## 🧹 Limpieza

```bash
terraform destroy
```

## 📝 Notas

- Esta infraestructura es **intencionalmente insegura**
- Usar solo en entornos de prueba/desarrollo
- No exponer datos sensibles reales
- Destruir recursos después de las pruebas
