FROM python:3.11-slim

# Metadata
LABEL maintainer="tu-email@example.com"
LABEL description="Cloud Custodian for AWS CSPM automation"

# Install Cloud Custodian and AWS provider
# (c7n-org is NOT used by this project — only the base `custodian` CLI is —
# and pinning it alongside c7n==0.9.52 creates an unresolvable dependency
# conflict since c7n-org 0.6.32 requires c7n==0.9.33 exactly)
RUN pip install --no-cache-dir \
    c7n==0.9.52 \
    boto3

# Create working directory
WORKDIR /custodian

# Set entrypoint
ENTRYPOINT ["custodian"]
CMD ["--help"]
