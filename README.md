# CSPM sin pagar licencias

Cloud Security Posture Management (CSPM) 100% open source: **Prowler** detecta, **Cloud Custodian** remedia, **Slack** avisa. Alternativa gratis a herramientas comerciales como Wiz, Prisma Cloud o Lacework ($8,000–$40,000/año).

Todo corre en Docker. No hay que instalar Prowler, Cloud Custodian ni Terraform en el host.

**Última corrida verificada:** 10 checks fallando → 5 resueltos automáticamente (50% de mejora, 0 críticas al final) en ~3 minutos, sin intervención manual. Detalle completo en el post: *(link cuando se publique)*.

## Qué es cada cosa

El repo tiene dos formas de usarlo, según si querés probar la demo o aplicar esto a tu propia cuenta AWS.

| Archivo | Qué es |
|---|---|
| **`cspm-automate.sh`** | El pipeline real: Prowler escanea → se analiza → Cloud Custodian remedia → Prowler valida → Slack avisa. Sin Terraform, no crea ni destruye nada. **Este es el que correrías contra tu propia infraestructura.** |
| **`run-cspm.sh`** | El demo de este repo. Hace lo mismo que `cspm-automate.sh`, pero además crea y destruye con Terraform la infraestructura vulnerable de juguete que se usa para tener algo que escanear. Es para probar el proyecto, no para una cuenta real. |
| `cspm-pipeline.sh` | Librería compartida por los dos scripts de arriba (logging, Slack, conteo de hallazgos, los 4 pasos del pipeline). No se corre directo. |
| `render-policies.sh` | Sustituye `${SLACK_WEBHOOK_URL}` en las policies de Cloud Custodian leyendo `.env`, y genera el archivo `.rendered.yml` que efectivamente se ejecuta. El webhook real nunca se commitea. |
| `cloud-custodian-policies/remediation-policies.yml` | Las 4 policies de remediación: cerrar SSH abierto, cerrar RDP abierto, bloquear acceso público en S3, forzar encriptación en S3. |
| `post-01-infraestructura-vulnerable/terraform/` | La infra de juguete (EC2, S3, Security Group, IAM Role) con vulnerabilidades intencionales, usada solo por `run-cspm.sh`. |
| `docker-compose.yml` | Define los 3 servicios: `terraform`, `prowler`, `custodian`. |
| `cspm-flow-diagram.html` / `.svg` / `.png` | Diagrama del ciclo completo (Deploy → Escaneo → Análisis → Remediación → Validación, con loop de mejora continua). |
| `.env.example` | Plantilla de variables: credenciales AWS + `SLACK_WEBHOOK_URL` (opcional). |

## Quickstart: probar la demo de este repo

```bash
git clone https://github.com/safernandez666/POC-CSPM.git
cd POC-CSPM
cp .env.example .env   # completar credenciales AWS (y opcionalmente SLACK_WEBHOOK_URL)

./run-cspm.sh
# elegí la opción 1: Deploy → Scan → Remediate → Validate
```

Cuando termines, destruí la infra de juguete para no dejar nada corriendo (opción 5 del menú, o `docker-compose run --rm terraform -chdir=/workspace destroy -auto-approve`).

## Usarlo contra tu propia cuenta AWS

```bash
cp .env.example .env   # tus credenciales, no las de la demo
```

Antes de correrlo, editá `cloud-custodian-policies/remediation-policies.yml`: el filtro `tag:Project: cspm-demo` en cada policy es específico de este repo. Cambialo por el tag (o filtro) que use tu organización para marcar qué recursos puede tocar Cloud Custodian.

```bash
# Dry-run primero, para ver qué matchearía sin tocar nada
docker-compose run --rm custodian run -d -s /custodian/output /custodian/policies/remediation-policies.yml

# Cuando confíes en el resultado
./cspm-automate.sh
```

## Notificaciones a Slack

Opcional. Si completás `SLACK_WEBHOOK_URL` en `.env`, cada remediación de Cloud Custodian manda un mensaje al canal con el recurso afectado, y al final del ciclo se manda un resumen con el antes/después.

Cloud Custodian no tiene un action simple para pegarle a un incoming webhook de Slack (el action `notify` está pensado para SNS/SQS + c7n-mailer). Las policies de este repo usan el action genérico `webhook`, cuyo `body` es una expresión JMESPath evaluada contra los recursos que matchearon:

```yaml
- type: webhook
  url: "${SLACK_WEBHOOK_URL}"
  batch: true
  body: "{text: join('', ['🔧 Cloud Custodian cerró SSH (22) en ', to_string(length(resources)), ' security group(s): ', join(', ', resources[].GroupId)])}"
```

## Estrategia de tags

Todos los recursos de la demo están taggeados con `Project=cspm-demo` para:

- Aislar la demo de cualquier otro recurso de la cuenta.
- Que Prowler escanee solo esto (`--resource-tag Project=cspm-demo`), no toda la cuenta.
- Que Cloud Custodian sepa exactamente qué puede tocar.

Sin un tag de aislamiento consistente, no le des un motor de remediación automática a nada.

## Resultados de la última corrida verificada

| | Antes | Después |
|---|---|---|
| Checks fallando | 10 (36%) | 4 (14%) |
| Checks pasando | 18 | 24 |
| Críticos | 4 | 0 |

Remediado automáticamente: SSH (22) cerrado, RDP (3389) cerrado, Block Public Access activado en el bucket S3, IMDSv2 forzado en la instancia EC2 (sin downtime — verificado por `LaunchTime` sin cambios).

**No remediado automáticamente, a propósito:**

- **Instancia con IP pública + instance profile con permisos amplios** — sacarle el profile o el acceso público puede romper lo que esa instancia esté haciendo; es una decisión de arquitectura, no un flag.
- **Secrets hardcodeados en el user data** — no se cambia en caliente; el user data se fija al lanzar la instancia, así que arreglarlo implica editar el launch template y reemplazar la instancia.

**Pendiente, pero sin nada de especial (simplemente no hay policy todavía):**

- IMDSv2 por default a nivel de cuenta (distinto del control por instancia que sí remediamos).
- Block Public Access a nivel de cuenta (distinto del control por bucket que sí remediamos).

## Costos

| Recurso | Costo mensual (24/7) |
|---|---|
| EC2 t2.micro | ~$8.50 (Free tier: $0) |
| S3 Bucket | ~$0.023/GB |
| VPC / Networking | Gratis |
| **Total dejándolo prendido** | **~$8–10/mes** |
| **Crear → probar → destruir el mismo día** | **~$0.30** |

Destruí la infra de la demo (`run-cspm.sh` opción 5) cuando termines de probarla.

## Advertencias

1. La infraestructura de `post-01-infraestructura-vulnerable/` es **intencionalmente insegura**. No la uses en producción ni cerca de datos reales.
2. Usá una cuenta AWS dedicada a testing, separada de producción.
3. `.env` está en `.gitignore` — nunca se sube al repo. Lo mismo el `.rendered.yml` que genera `render-policies.sh` con el webhook real.
4. Antes de correr `custodian run` sin `--dryrun` contra una cuenta real, revisá el filtro de tag en cada policy.

## Herramientas

- [Prowler](https://github.com/prowler-cloud/prowler) — 600+ checks de seguridad AWS.
- [Cloud Custodian](https://cloudcustodian.io/) — motor de políticas para governance y remediación.
- [Terraform](https://www.terraform.io/) — infraestructura como código (solo para la demo).
- [Docker](https://www.docker.com/) — todo containerizado.

## Serie de posts

1. **Infraestructura vulnerable + ciclo completo** — este repo. En progreso.
2. Análisis de hallazgos de Prowler y cómo priorizar qué remediar primero.
3. Cloud Custodian a fondo: sintaxis de policies y filtros.
4. Notificaciones y observabilidad del ciclo de remediación.

## Licencia

MIT — ver [LICENSE](LICENSE).

## Autor

Santiago Fernández — [@safernandez666](https://github.com/safernandez666) · [blog.santiagoagustinfernandez.com](https://blog.santiagoagustinfernandez.com)
