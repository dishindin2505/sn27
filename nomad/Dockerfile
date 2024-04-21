# Build stage
FROM debian:bookworm-slim as core

ENV DEBIAN_FRONTEND=noninteractive
# Install wget and gnupg before using them
RUN apt -y update && apt-get install -y \
    wget \
    gnupg \
    lsb-release

# Now use wget and gpg to add the HashiCorp repository
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list

# Update apt and install your desired packages
RUN apt -y update && apt-get install -y \
    curl \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates

FROM core as consul-sidecar
RUN apt update -y && apt install -y consul
ENTRYPOINT ["consul "]

FROM core as consul-gateway
RUN apt update -y && apt install -y consul
ENTRYPOINT ["consul" "agent" "-server", "-bind", "127.0.0.1", "-data-dir", "/opt/consul"]

FROM consul-img as nomad-img
RUN apt update -y && apt install -y nomad
ENTRYPOINT ["nomad"]



