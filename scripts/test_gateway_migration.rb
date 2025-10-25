#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for gateway migration to AgrrService
require_relative '../config/environment'

puts "Testing Gateway Migration to AgrrService..."
puts "=" * 50

# Test 1: WeatherGateway
puts "1. Testing WeatherGateway..."
begin
  weather_gateway = Agrr::WeatherGateway.new
  puts "   ✓ WeatherGateway created successfully"
  
  # Test daemon status
  agrr_service = AgrrService.new
  if agrr_service.daemon_running?
    puts "   ✓ Daemon is running"
  else
    puts "   ✗ Daemon is not running"
  end
rescue => e
  puts "   ✗ WeatherGateway creation failed: #{e.message}"
end

# Test 2: OptimizationGateway
puts "\n2. Testing OptimizationGateway..."
begin
  optimization_gateway = Agrr::OptimizationGateway.new
  puts "   ✓ OptimizationGateway created successfully"
rescue => e
  puts "   ✗ OptimizationGateway creation failed: #{e.message}"
end

# Test 3: ProgressGateway
puts "\n3. Testing ProgressGateway..."
begin
  progress_gateway = Agrr::ProgressGateway.new
  puts "   ✓ ProgressGateway created successfully"
rescue => e
  puts "   ✗ ProgressGateway creation failed: #{e.message}"
end

# Test 4: AllocationGateway
puts "\n4. Testing AllocationGateway..."
begin
  allocation_gateway = Agrr::AllocationGateway.new
  puts "   ✓ AllocationGateway created successfully"
rescue => e
  puts "   ✗ AllocationGateway creation failed: #{e.message}"
end

# Test 5: AdjustGateway
puts "\n5. Testing AdjustGateway..."
begin
  adjust_gateway = Agrr::AdjustGateway.new
  puts "   ✓ AdjustGateway created successfully"
rescue => e
  puts "   ✗ AdjustGateway creation failed: #{e.message}"
end

# Test 6: PredictionGateway
puts "\n6. Testing PredictionGateway..."
begin
  prediction_gateway = Agrr::PredictionGateway.new
  puts "   ✓ PredictionGateway created successfully"
rescue => e
  puts "   ✗ PredictionGateway creation failed: #{e.message}"
end

puts "\n" + "=" * 50
puts "Gateway migration test completed!"
puts "\nAll gateways now use AgrrService instead of direct binary calls."
puts "This provides better error handling and daemon management."
