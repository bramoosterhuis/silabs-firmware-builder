FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

# Install basic tools and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bzip2 \
    ca-certificates \
    curl \
    git \
    git-lfs \
    gnupg \
    jq \
    libgl1 \
    libglib2.0-0\
    lsb-release \
    make \
    patch \
    python3 \
    python3-pip \
    python3-venv \
    python3-jinja2 \
    python3-ruamel.yaml \
    python3-pyelftools \
    unzip \
    wget \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install yq separately (YAML processor)
RUN curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

# Add Eclipse Adoptium repository and install Java 21
RUN wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor | tee /etc/apt/trusted.gpg.d/adoptium.gpg > /dev/null \
    && echo "deb https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/adoptium.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends temurin-21-jdk \
    && rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64
ENV PATH="$PATH:$JAVA_HOME/bin"

# Verify Python 3.10 is available and jinja2 works
RUN python3 --version \
    && python3 -c "import jinja2; print('System Python has jinja2:', jinja2.__version__)"

# Copy requirements and set up virtual environment
COPY requirements.txt /tmp/
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

# Install Simplicity Commander
RUN curl -O https://www.silabs.com/documents/login/software/SimplicityCommander-Linux.zip \
    && unzip -q SimplicityCommander-Linux.zip \
    && tar -C /opt -xjf SimplicityCommander-Linux/Commander_linux_x86_64_*.tar.bz \
    && rm -rf SimplicityCommander-Linux SimplicityCommander-Linux.zip

ENV PATH="$PATH:/opt/commander"

# Install Silicon Labs Configurator (slc)
RUN curl -O https://www.silabs.com/documents/login/software/slc_cli_linux.zip \
    && unzip -q -d /opt slc_cli_linux.zip \
    && rm slc_cli_linux.zip

ENV PATH="$PATH:/opt/slc_cli"

# Install GCC Embedded Toolchain 12.2.rel1
RUN curl -O https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu/12.2.rel1/binrel/arm-gnu-toolchain-12.2.rel1-x86_64-arm-none-eabi.tar.xz \
    && tar -C /opt -xf arm-gnu-toolchain-12.2.rel1-x86_64-arm-none-eabi.tar.xz \
    && rm arm-gnu-toolchain-12.2.rel1-x86_64-arm-none-eabi.tar.xz

# Install Simplicity SDK 2024.6.2
RUN curl -o simplicity_sdk_2024.6.2.zip -L https://github.com/SiliconLabs/simplicity_sdk/releases/download/v2024.6.2/gecko-sdk.zip \
    && unzip -q -d simplicity_sdk_2024.6.2 simplicity_sdk_2024.6.2.zip \
    && rm simplicity_sdk_2024.6.2.zip

# Install Gecko SDK 4.4.6
RUN curl -o gecko_sdk_4.4.6.zip -L https://github.com/SiliconLabs/gecko_sdk/releases/download/v4.4.6/gecko-sdk.zip \
    && unzip -q -d gecko_sdk_4.4.6 gecko_sdk_4.4.6.zip \
    && rm gecko_sdk_4.4.6.zip

# Install ZCL Advanced Platform (ZAP)
RUN curl -o zap_2024.09.27.zip -L https://github.com/project-chip/zap/releases/download/v2024.09.27/zap-linux-x64.zip \
    && unzip -q -d /opt/zap zap_2024.09.27.zip \
    && rm zap_2024.09.27.zip

ENV STUDIO_ADAPTER_PACK_PATH="/opt/zap"

# Create non-root user
ARG USERNAME=builder
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME

USER $USERNAME
WORKDIR /build
