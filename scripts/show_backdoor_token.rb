#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to display the current backdoor token configuration

require_relative '../config/environment'

puts "=" * 70
puts "BACKDOOR TOKEN CONFIGURATION"
puts "=" * 70
puts ""

if BackdoorConfig.enabled?
  puts "✅ Backdoor is ENABLED"
  puts ""
  puts "Current Token: #{BackdoorConfig.token}"
  puts ""
  puts "API Endpoints:"
  puts "  GET /api/v1/backdoor/status"
  puts "  GET /api/v1/backdoor/health"
  puts ""
  puts "Usage:"
  puts "  curl -H 'X-Backdoor-Token: #{BackdoorConfig.token}' http://localhost:3000/api/v1/backdoor/status"
  puts "  curl 'http://localhost:3000/api/v1/backdoor/status?token=#{BackdoorConfig.token}'"
  puts ""
else
  puts "❌ Backdoor is DISABLED"
  puts ""
  puts "To enable, set the environment variable:"
  puts "  export AGRR_BACKDOOR_TOKEN='<your-secret-token>'"
  puts ""
  puts "For Docker Compose, add to docker-compose.yml:"
  puts "  environment:"
  puts "    - AGRR_BACKDOOR_TOKEN=<your-secret-token>"
  puts ""
  puts "You can generate a random token with:"
  puts "  ruby -e \"require 'securerandom'; puts SecureRandom.hex(32)\""
end

puts "=" * 70

