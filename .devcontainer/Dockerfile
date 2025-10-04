# [Choice] Ruby version: 3.3, 3.2, 3.1
ARG VARIANT=3.3
FROM mcr.microsoft.com/devcontainers/ruby:${VARIANT}

# Install Rails dependencies
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    sqlite3 \
    libsqlite3-dev \
    nodejs \
    npm \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install latest Node.js LTS
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs

# Set working directory
WORKDIR /workspace

# Configure bundler
RUN gem update --system && \
    gem install bundler && \
    bundle config set --global path '/usr/local/bundle'

# Install Rails
RUN gem install rails

# Default command
CMD ["/bin/bash"]






