# Use the official Ruby image as the base image
FROM ruby:3.3.9-slim

# Install system dependencies (including SQLite, YAML, and Node.js)
RUN apt-get update -qq && apt-get install -y \
    build-essential \
    libsqlite3-dev \
    libyaml-dev \
    curl \
    gnupg \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

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

# Build JavaScript assets
RUN npm run build

# Precompile Rails assets (Propshaft)
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

# Create a non-root user and set permissions
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app && chown -R appuser:appuser /usr/local/bundle
# Ensure bundle cache directory is writable
RUN mkdir -p /usr/local/bundle/cache && chown -R appuser:appuser /usr/local/bundle/cache
# Fix tmp directory permissions
RUN chown -R appuser:appuser /app/tmp
USER appuser

# Expose port 3000
EXPOSE 3000

# Start the Rails server
CMD ["rails", "server", "-b", "0.0.0.0"]
