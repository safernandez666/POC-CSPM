# CSPM Sin Pagar Licencias 🐳

Implementación práctica de Cloud Security Posture Management (CSPM) usando herramientas open source gratuitas: **Prowler** para detección y **Cloud Custodian** para remediación automática.

**🐳 TODO en Docker** - No instales nada excepto Docker. Funciona en cualquier máquina.

Alternativa open source a herramientas comerciales como Wiz, Prisma Cloud, y Lacework.

## 🚀 Quickstart con Docker (5 minutos)

```bash
# 1. Clonar
git clone https://github.com/tu-usuario/POC-CSPM.git
cd POC-CSPM

# 2. Configurar AWS credentials
cp .env.example .env
nano .env  # Agregar tus credenciales AWS

# 3. Ejecutar ciclo completo
./run-cspm.sh

# 4. Ver resultados
open prowler-output/prowler-output-*.html

# 5. Cleanup
docker-compose run --rm terraform -chdir=/workspace destroy
```

## 🎯 Objetivo de la Serie

Aprender a:
1. Detectar vulnerabilidades en AWS con Prowler
2. Analizar y priorizar hallazgos de seguridad
3. Automatizar remediación con Cloud Custodian
4. Implementar escaneo continuo y remediación automática

## 📚 Posts de la Serie

### ✅ Parte 1: Infraestructura Vulnerable y Detección
**Estado:** Completado  
**Directorio:** [`post-01-infraestructura-vulnerable/`](./post-01-infraestructura-vulnerable/)

- Crear infraestructura AWS vulnerable con Terraform
- Usar tags para aislar recursos demo de producción
- Escanear con Prowler filtrando por tags
- Analizar 23+ vulnerabilidades detectadas

**Hallazgos:** 46% failed (23 checks), 54% passed (27 checks)

### 🚧 Parte 2: Análisis de Hallazgos y Priorización
**Estado:** En desarrollo  
**Directorio:** `post-02-analisis-hallazgos/`

- Comprender reportes de Prowler (HTML, CSV, JSON)
- Priorizar por severidad y riesgo de negocio
- Mapear a frameworks de compliance (CIS, NIST, PCI-DSS)

### 🚧 Parte 3: Introducción a Cloud Custodian
**Estado:** Planificado  
**Directorio:** `post-03-cloud-custodian-intro/`

- Instalación y configuración de Cloud Custodian
- Sintaxis de políticas y filtros
- Primer política: detectar recursos sin tags

### 🚧 Parte 4: Remediación Automática
**Estado:** Planificado  
**Directorio:** `post-04-remediacion-automatica/`

- Crear políticas de Cloud Custodian para remediar hallazgos de Prowler
- Acciones automáticas: cerrar Security Groups, encriptar S3, etc.
- Notificaciones con SNS/Slack

### 🚧 Parte 5: Automatización Continua
**Estado:** Planificado  
**Directorio:** `post-05-automatizacion-continua/`

- Ciclo completo: escaneo → detección → remediación
- Integración con CI/CD
- Dashboards y métricas

## 🚀 Quickstart

### Requisitos Previos

- AWS CLI configurado
- Terraform >= 1.0
- Docker (para Prowler)
- Cuenta AWS (recomendado: cuenta dedicada para testing)

### Parte 1: Infraestructura Vulnerable

```bash
# 1. Clonar repositorio
git clone https://github.com/tu-usuario/POC-CSPM.git
cd POC-CSPM

# 2. Configurar AWS credentials
export AWS_ACCESS_KEY_ID=tu_access_key
export AWS_SECRET_ACCESS_KEY=tu_secret_key
export AWS_DEFAULT_REGION=us-east-1

# 3. Desplegar infraestructura vulnerable
cd post-01-infraestructura-vulnerable/terraform
terraform init
terraform apply

# 4. Escanear con Prowler (filtrado por tags)
cd ../..
mkdir -p prowler-output
docker run --rm \
  -e AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY \
  -v $(pwd)/prowler-output:/prowler/output \
  public.ecr.aws/prowler-cloud/prowler:stable aws \
  --resource-tag Project=cspm-demo \
  --output-formats html csv json-ocsf \
  --output-directory /prowler/output

# 5. Ver reporte
open prowler-output/prowler-output-*.html

# 6. ⚠️ IMPORTANTE: Destruir infraestructura cuando termines
cd post-01-infraestructura-vulnerable/terraform
terraform destroy
```

## 🏷️ Estrategia de Tags

Todos los recursos de la demo están taggeados con `Project=cspm-demo` para:

- ✅ Aislar completamente de recursos productivos
- ✅ Escanear SOLO los recursos de la demo con Prowler
- ✅ Evitar alertas falsas en infraestructura real
- ✅ Facilitar cleanup con `terraform destroy`

**Comando Prowler con filtro:**
```bash
prowler aws --resource-tag Project=cspm-demo
```

## 📊 Resultados Esperados

### Prowler Scan (Parte 1)

- **Total checks:** 75
- **Failed:** 23 (46%)
- **Passed:** 27 (54%)

**Desglose por servicio:**
- EC2: 9 fallas (2 críticas, 4 altas, 2 medias, 1 baja)
- S3: 14 fallas (2 críticas, 2 altas, 6 medias, 4 bajas)

**Frameworks evaluados:** 44 (CIS, NIST, PCI-DSS, HIPAA, ISO27001, SOC2, etc.)

## ⚠️ Advertencias de Seguridad

**🚨 IMPORTANTE:**

1. **No usar en producción:** Esta infraestructura es INTENCIONALMENTE INSEGURA
2. **Cuenta dedicada:** Usar cuenta AWS separada para testing
3. **Destruir después:** Ejecutar `terraform destroy` al terminar
4. **No exponer datos reales:** No subir información sensible a los buckets S3
5. **Costos:** Destruir recursos para evitar cobros (~$8-10/mes si se deja corriendo)

## 💰 Costos Estimados

| Recurso | Costo mensual (24/7) |
|---------|---------------------|
| EC2 t2.micro | $8.50 (Free tier: $0) |
| S3 Bucket | $0.023 por GB |
| VPC/Networking | Gratis |
| **Total** | **~$8-10/mes** (Free tier: $0) |

**Recomendación:** Crear → Probar → Destruir el mismo día = $0.30

## 🛠️ Herramientas Utilizadas

- **[Prowler](https://github.com/prowler-cloud/prowler)** - Security assessment tool
- **[Cloud Custodian](https://cloudcustodian.io/)** - Cloud governance & remediation
- **[Terraform](https://www.terraform.io/)** - Infrastructure as Code
- **[Docker](https://www.docker.com/)** - Containerización de Prowler

## 📖 Recursos Adicionales

- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)
- [NIST 800-53 Security Controls](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final)
- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)
- [Prowler Documentation](https://docs.prowler.com/)
- [Cloud Custodian Documentation](https://cloudcustodian.io/docs/)

## 🤝 Contribuciones

¿Encontraste un bug? ¿Tienes una mejora? ¡Pull requests bienvenidos!

## 📝 Licencia

MIT License - Ver [LICENSE](LICENSE) para detalles.

## ✍️ Autor

Santiago Fernandez - [@tu-usuario](https://github.com/tu-usuario)

Blog: [tu-blog.hashnode.dev](https://tu-blog.hashnode.dev)

---

**⭐ Si este proyecto te ayudó, dale una estrella en GitHub!**
