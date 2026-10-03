# Node 22 on Debian bookworm. agentic-qe 3.14.7 requires Node >=22.13.
FROM mcr.microsoft.com/devcontainers/typescript-node:22-bookworm

# Build deps for nagual-qe (Rust + SQLite + OpenSSL), plus the small tools the exercises use.
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential pkg-config libssl-dev sqlite3 libsqlite3-dev \
      tmux jq ripgrep tree less postgresql-client redis-tools \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# Bigger terminal font is set in VS Code settings; this just makes the prompt readable on a projector.
RUN echo 'export PS1="\[\e[1;34m\]masterclass\[\e[0m\]:\w$ "' >> /home/node/.bashrc \
 && echo 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"' >> /home/node/.bashrc \
 && mkdir -p /home/node/.local/bin && chown -R node:node /home/node/.local

USER node
