#!/usr/bin/env ruby

puts "Starting minimal test..."

# Load only what we need
require_relative "config/boot"

puts "Boot loaded successfully"

require "rails/all"

puts "Rails loaded successfully"

ENV["RAILS_ENV"] = "test"

require_relative "config/application"

puts "Application loaded successfully"

Rails.application.initialize!

puts "Rails initialized successfully"

puts "Database configuration for test:"
config = Rails.application.config.database_configuration["test"]
puts config.inspect

puts "Minimal test completed successfully!"
