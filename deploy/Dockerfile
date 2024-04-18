# Build stage
FROM ubuntu:18.04 as foundation
RUN DEBIAN_FRONTEND=noninteractive 
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Provision dependencies
RUN apt update -y && apt -y install \
                        nomad \
                        vault \
                        consul \
                        supervisor

CMD ["nomad", "agent", "-dev"]
