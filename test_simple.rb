#!/usr/bin/env ruby

require_relative "config/environment"

puts "Rails environment loaded successfully!"
puts "Database configuration:"
puts Rails.application.config.database_configuration["test"]

# Test basic functionality
begin
  ActiveRecord::Base.connection.execute("SELECT 1")
  puts "Database connection successful!"
rescue => e
  puts "Database connection failed: #{e.message}"
end

puts "Test completed!"
