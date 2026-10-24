FROM mcr.microsoft.com/devcontainers/base:debian

# hadolint ignore=DL3008

RUN cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        libwww-mechanize-perl \
        libperl-critic-perl \
        libxml-simple-perl \
        perl-doc \
        perltidy \
        ca-certificates \
        docker-ce-cli \
        docker-buildx-plugin \
        moreutils \
        vim \
        jq \
    && apt-get autoremove -y \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/lib/execline/bin /command
