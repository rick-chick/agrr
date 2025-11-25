# Use the official Ruby image as the base image
FROM ruby:3.3.10-slim

# Install system dependencies (including SQLite, YAML, and Node.js)
# Note: We need to downgrade zlib to 1.2.x for agrr binary compatibility
RUN apt-get update -qq && apt-get install -y \
    build-essential \
    libsqlite3-dev \
    libyaml-dev \
    curl \
    gnupg \
    wget \
    chromium \
    chromium-driver \
    fonts-liberation \
    libatk-bridge2.0-0 \
    libasound2 \
    libgbm1 \
    libgtk-3-0 \
    libnss3 \
    libxss1 \
    libxi6 \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

ENV CHROME_BIN=/usr/bin/chromium \
    CHROMEDRIVER_PATH=/usr/bin/chromedriver

# Install zlib 1.2.13 (compatible with agrr binary built on host)
# The agrr binary was built with zlib 1.2.x and is incompatible with zlib 1.3.x
RUN cd /tmp \
    && wget https://github.com/madler/zlib/archive/refs/tags/v1.2.13.tar.gz \
    && tar -xzf v1.2.13.tar.gz \
    && cd zlib-1.2.13 \
    && ./configure --prefix=/usr/local \
    && make \
    && make install \
    && ldconfig \
    && cd / \
    && rm -rf /tmp/zlib-1.2.13* /tmp/v1.2.13.tar.gz

# Set the working directory
WORKDIR /app

# Copy package.json and install Node.js dependencies
COPY package.json ./
RUN npm install

# Copy Gemfile and Gemfile.lock (if exists)
COPY Gemfile ./
COPY Gemfile.lock* ./

# Install gems and ensure they're properly installed
RUN bundle config set --local deployment 'false' && \
    bundle config set --local without '' && \
    bundle install

# Copy the rest of the application
COPY . .

# Create storage directory for SQLite databases and tmp directories
RUN mkdir -p storage tmp/cache tmp/pids tmp/sockets

# Ensure entrypoint scripts have execute permissions
# ボリュームマウントで上書きされる可能性があるが、ベースイメージとして権限を設定
RUN chmod +x /app/scripts/*.sh 2>/dev/null || true

# Build JavaScript assets
# Note: This runs as root during image build, but app/assets/builds/ is excluded from
# volume mounts in docker-compose.yml, so it won't cause permission issues in development.
RUN npm run build

# Precompile Rails assets (Propshaft)
# Note: javascript:build will run again, but it uses node_modules/.bin/esbuild (no network needed)
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

# Create a non-root user and set permissions
# Note: app/assets/builds/ ownership is set here, but in development it's isolated
# in the container via volume exclusion, so host permissions are unaffected.
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app && chown -R appuser:appuser /usr/local/bundle
# Ensure bundle cache directory is writable
RUN mkdir -p /usr/local/bundle/cache && chown -R appuser:appuser /usr/local/bundle/cache
# Fix tmp directory permissions
RUN chown -R appuser:appuser /app/tmp

# Note: agrr binary is mounted via volume in docker-compose.yml
# Development: Uses /app/lib/core/agrr (volume mount from host)
# Production: agrr binary should be built and placed in lib/core/ before docker build
# No need to copy to /usr/local/bin/ - we use explicit paths in entrypoint scripts

# Ensure /tmp is writable for daemon socket
RUN chmod 1777 /tmp

USER appuser

# Expose port 3000
EXPOSE 3000

# Start the Rails server
CMD ["rails", "server", "-b", "0.0.0.0"]
