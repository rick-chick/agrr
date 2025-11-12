#!/bin/bash

# Development environment setup script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "Setting up development environment..."

# Check if Ruby is installed
if ! command -v ruby &> /dev/null; then
    print_error "Ruby is not installed. Please install Ruby 3.3.10."
    exit 1
fi

# Check Ruby version
RUBY_VERSION=$(ruby -v | cut -d' ' -f2 | cut -d'p' -f1)
if [[ "$RUBY_VERSION" != "3.3.10" ]]; then
    print_error "Ruby version $RUBY_VERSION is incorrect. Please install Ruby 3.3.10."
    exit 1
fi

print_status "Ruby version: $RUBY_VERSION"

# Check if Bundler is installed
if ! command -v bundle &> /dev/null; then
    print_status "Installing Bundler..."
    gem install bundler
fi

# Install gems
print_status "Installing gems..."
bundle install

# Setup database
print_status "Setting up database..."
bundle exec rails db:create
bundle exec rails db:migrate

# Create storage directories
print_status "Creating storage directories..."
mkdir -p storage
mkdir -p tmp/storage

print_status "Development environment setup completed!"
print_warning "You can now run 'rails server' to start the development server"
print_warning "Or use 'docker-compose up' to run with Docker"
