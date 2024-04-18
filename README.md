# Build stage
FROM ubuntu:18.04 as foundation
RUN DEBIAN_FRONTEND=noninteractive 
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Provision dependencies
RUN apt update -y && apt -y install \
                        build-essential \
                        python-dev \
                        python-six \
                        python-virtualenv \
                        libcurl4-nss-dev \
                        libsasl2-dev \
                        libsasl2-modules \
                        maven \
                        libapr1-dev \
                        libsvn-dev \
                        zlib1g-dev \
                        iputils-ping \
                        openjdk-8-jdk \
                        autoconf \
                        libtool \
                        build-essential \
                        supervisor

FROM foundation as mesos-build
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH
WORKDIR /tmp
RUN wget https://downloads.apache.org/mesos/1.11.0/mesos-1.11.0.tar.gz
    tar -zxf mesos-1.11.0.tar.gz
    mkdir build && \
    cd build && \
    ../configure && \
    make

ENV MESOS_NATIVE_JAVA_LIBRARY=/usr/local/lib/libmesos.so
ENV LD_LIBRARY_PATH=:/usr/local/nvidia/lib:/usr/local/nvidia/lib64
WORKDIR /tmp/mesos-1.11.0/build
RUN make install && \
    mv /tmp/mesos-1.11.0/build/bin/* /bin

FROM mesos-build as runpod-config
COPY /runpod/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
CMD ["/usr/bin/supervisord"]
