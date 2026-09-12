FROM debian:13

ENV DEBIAN_FRONTEND=noninteractive

# Common dev tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    build-essential \
    ripgrep \
    jq \
    python3 \
    python3-pip \
    nodejs \
    npm \
    fzf \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# opencode (installed system-wide)
RUN curl -fsSL https://opencode.ai/install | bash \
    && mv /root/.opencode/bin/opencode /usr/local/bin/opencode

# Non-root user
RUN useradd -ms /bin/bash dev
RUN mkdir -p /home/dev/.local/share /home/dev/.local/state && chown -R dev:dev /home/dev/.local

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh && chown root:root /usr/local/bin/entrypoint.sh

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
