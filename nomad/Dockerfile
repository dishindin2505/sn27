# Build stage
FROM debian:bookworm-slim as core

RUN DEBIAN_FRONTEND=noninteractive \
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list \
    apt update -y && apt install -y  \
                        wget \
                        curl \
                        unzip \
                        gnupg \
                        software-properties-common \
                        apt-transport-https \
                        ca-certificates \
                        lsb-release 

FROM core as consul-img
RUN apt update -y && apt install -y consul

FROM consul-img as nomad-img
RUN apt update -y && apt install -y nomad
ENTRYPOINT ["nomad"]



