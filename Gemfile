source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.3.9"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.0"

# Use Propshaft for asset pipeline (Rails 8 default)
gem "propshaft", "= 1.3.1"

# Use jsbundling-rails for JavaScript bundling
gem "jsbundling-rails", "= 1.3.1"

# Hotwire's SPA-like page accelerator and realtime updates
gem "turbo-rails", "= 2.0.17"
gem "stimulus-rails", "= 1.3.4"

# Use SQLite3 as the database for Active Record (production-ready with Rails 8)
gem "sqlite3", ">= 2.1"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Solid Queue for background jobs [https://github.com/rails/solid_queue]
gem "solid_queue"

# Use Solid Cache for caching [https://github.com/rails/solid_cache]
gem "solid_cache"

# Use Solid Cable for Action Cable adapter [https://github.com/rails/solid_cable]
gem "solid_cable"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ mswin mswin64 mingw x64_mingw jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# AWS SDK for S3
gem "aws-sdk-s3", require: false

# Environment variables
gem "dotenv-rails"

# CORS support
gem "rack-cors"

# OAuth authentication
gem "omniauth"
gem "omniauth-google-oauth2"
gem "omniauth-rails_csrf_protection"

# Enhance SQLite for production use
# gem "litestack"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mswin mswin64 mingw x64_mingw ]

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/Shopify/rubocop-shopify]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :production do
  gem "rack-attack", "= 6.8.0"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
  
  # Code coverage
  gem "simplecov", "= 0.22.0", require: false
  
  # Database cleanup for system tests
  gem "database_cleaner-active_record", "= 2.2.2"
  
  # Test data factories
  gem "factory_bot_rails", "= 6.5.1"
end
