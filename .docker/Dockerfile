# Docker - Pull base image
FROM osrf/ros:kilted-desktop-full

# Environment - Setup ARGs and ENV
ARG DEBIAN_FRONTEND=noninteractive

# User configuration
ARG USER_NAME=ros
ARG USER_PASSWORD=ros
ARG USER_UID=1000
ARG USER_GID=1000

ENV UID=$USER_UID
ENV GID=$USER_GID
ENV USER=$USER_NAME
ENV SHELL=/bin/bash
ENV TZ=Europe/Berlin
ENV TERM=xterm-256color
ENV PATH=$PATH:/home/$USER/.cargo/bin:/home/$USER/.local/bin

# Timezone setup
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# System packages + Rust dependencies
RUN apt-get update && apt-get install -y \
    bash-completion \
    curl \
    git \
    git-lfs \
    lsb-release \
    sudo \
    trash-cli \
    tree \
    vim \
    wget \
    build-essential \
    cmake \
    gdb \
    net-tools \
    python3 \
    python3-colcon-clean \
    python3-pip \
    python3-venv \
    ros-dev-tools \
    ros-kilted-rmw-cyclonedds-cpp \
    ros-kilted-rqt* \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Make python/pip available as python/pip
RUN [ ! -e /usr/bin/python ] && ln -s /usr/bin/python3 /usr/bin/python || true && \
    [ ! -e /usr/bin/pip ] && ln -s /usr/bin/pip3 /usr/bin/pip || true

# Install rosdep
RUN rosdep init || true

# Handle existing ubuntu user conflicts (if any)
RUN if id "ubuntu" &>/dev/null; then \
if [ "$(id -u ubuntu)" = "${UID}" ] || [ "$(id -g ubuntu)" = "${GID}" ]; then \
userdel -r ubuntu 2>/dev/null || true; \
groupdel ubuntu 2>/dev/null || true; \
fi; \
fi

# Handle existing group with same GID
RUN if getent group "${GID}" &>/dev/null; then \
groupdel "$(getent group "${GID}" | cut -d: -f1)" 2>/dev/null || true; \
fi

# Create user
RUN echo "Creating user ${USER} with UID ${UID} and GID ${GID}..." && \
groupadd --gid "${GID}" "${USER}" && \
useradd --uid "${UID}" --gid "${GID}" -m --shell $(which bash) "${USER}" -G sudo && \
echo "${USER}:${USER_PASSWORD}" | chpasswd && \
echo "%sudo ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/sudogrp && \
chmod 0440 /etc/sudoers.d/sudogrp && \
chown ${UID}:${GID} -R /home/${USER}

# Switch to user
USER $USER
WORKDIR /home/$USER

# Install Rust
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

# Install just via cargo
RUN . "$HOME/.cargo/env" && \
    cargo install just

# Workspace
RUN mkdir -p /home/$USER/workspace

# ROS environment setup
RUN echo "source /opt/ros/kilted/setup.bash" >> /home/$USER/.bashrc

# rosdep update (safe ignore failures in container builds)
RUN rosdep update || true

# Entry point
ENTRYPOINT ["/bin/bash", "-c", "exec bash"]