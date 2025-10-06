# AWS App Runner optimized Dockerfile
FROM ruby:3.2.0-slim

# Install system dependencies (including Node.js)
RUN apt-get update -qq && apt-get install -y \
    build-essential \
    libpq-dev \
    curl \
    gnupg \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /app

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install gems
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install

# Copy package.json and install Node.js dependencies
COPY package.json ./
RUN npm install

# Copy the rest of the application
COPY . .

# Build JavaScript assets
RUN npm run build

# Precompile assets
RUN RAILS_ENV=production bundle exec rails assets:precompile

# Create a non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Expose port 3000
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/up || exit 1

# Start the Rails server
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-e", "production"]
