# Build stage
FROM debian:bookworm-slim as foundation

RUN DEBIAN_FRONTEND=noninteractive 
RUN apt update -y && apt install -y  \
                        wget \
                        curl \
                        unzip \
                        gnupg \
                        software-properties-common \
                        apt-transport-https \
                        ca-certificates \
                        lsb-release \
                        sudo \
                        supervisor 
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Provision dependencies
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list \
    apt update -y && apt -y install \
                        nomad \
                        vault \
                        consul \
                        supervisor \
                        firejail \
                        selinux-utils 
                        
ENTRYPOINT ["nomad"]
CMD ["agent", "-dev"]
