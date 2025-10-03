# Use the official Ruby image as the base image
FROM ruby:3.3.6-slim

# Install system dependencies (including SQLite)
RUN apt-get update -qq && apt-get install -y \
    build-essential \
    libsqlite3-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /app

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install gems
RUN bundle install

# Copy the rest of the application
COPY . .

# Create storage directory for SQLite databases
RUN mkdir -p storage

# Create a non-root user and set permissions
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app && chown -R appuser:appuser /usr/local/bundle
USER appuser

# Expose port 3000
EXPOSE 3000

# Start the Rails server
CMD ["rails", "server", "-b", "0.0.0.0"]
