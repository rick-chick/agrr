#!/usr/bin/env ruby
# frozen_string_literal: true

# Google OAuth Configuration Checker
# Usage: ruby scripts/check_oauth_config.rb

require_relative '../config/environment'

puts "🔍 Google OAuth Configuration Check"
puts "=" * 50

# Check environment variables
client_id = ENV['GOOGLE_CLIENT_ID']
client_secret = ENV['GOOGLE_CLIENT_SECRET']

puts "Environment: #{Rails.env}"
puts ""

puts "📋 Configuration Status:"
puts "  GOOGLE_CLIENT_ID: #{client_id.present? ? '✅ SET' : '❌ NOT SET'}"
puts "  GOOGLE_CLIENT_SECRET: #{client_secret.present? ? '✅ SET' : '❌ NOT SET'}"

if client_id.present? && client_secret.present?
  puts ""
  puts "✅ Google OAuth is properly configured!"
  puts ""
  puts "🔗 OAuth URLs:"
  puts "  Login URL: #{Rails.application.routes.url_helpers.auth_login_path}"
  puts "  OAuth URL: /auth/google_oauth2"
  puts "  Callback URL: /auth/google_oauth2/callback"
  puts ""
  puts "🌐 Google Console Setup:"
  puts "  1. Go to https://console.developers.google.com/"
  puts "  2. Create or select your project"
  puts "  3. Enable Google+ API"
  puts "  4. Create OAuth 2.0 credentials"
  puts "  5. Add authorized redirect URI: #{ENV['RAILS_HOST'] || 'https://your-domain.com'}/auth/google_oauth2/callback"
else
  puts ""
  puts "❌ Google OAuth is NOT configured!"
  puts ""
  puts "🔧 Setup Instructions:"
  puts "  1. Set GOOGLE_CLIENT_ID environment variable"
  puts "  2. Set GOOGLE_CLIENT_SECRET environment variable"
  puts "  3. Restart the application"
  puts ""
  puts "💡 For production deployment:"
  puts "  - Set these variables in your hosting platform"
  puts "  - Ensure they are properly secured"
end

puts ""
puts "🔍 OmniAuth Middleware Status:"
begin
  # Check if OmniAuth middleware is loaded
  middleware_stack = Rails.application.middleware
  omniauth_middleware = middleware_stack.detect { |m| m.first.include?('OmniAuth') }
  
  if omniauth_middleware
    puts "  ✅ OmniAuth middleware is loaded"
    puts "  Provider: #{omniauth_middleware.first}"
  else
    puts "  ❌ OmniAuth middleware not found"
  end
rescue => e
  puts "  ⚠️  Could not check middleware: #{e.message}"
end

puts ""
puts "=" * 50
