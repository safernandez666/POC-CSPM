FROM python:3.11-slim

# Metadata
LABEL maintainer="tu-email@example.com"
LABEL description="Cloud Custodian for AWS CSPM automation"

# Install Cloud Custodian and AWS provider
RUN pip install --no-cache-dir \
    c7n==0.9.52 \
    c7n-org==0.6.32 \
    boto3

# Create working directory
WORKDIR /custodian

# Set entrypoint
ENTRYPOINT ["custodian"]
CMD ["--help"]
