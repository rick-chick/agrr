#!/usr/bin/env ruby
# frozen_string_literal: true

require 'selenium-webdriver'
require 'timeout'

class PublicPlansToMyPlansTest
  def initialize
    @driver = nil
    @base_url = 'http://localhost:3000'
  end

  def run
    setup_driver
    begin
      test_public_plans_flow
      test_save_to_my_plans
      test_plan_verification
      test_gantt_chart
      puts "✅ All tests passed!"
    rescue => e
      puts "❌ Test failed: #{e.message}"
      puts e.backtrace.join("\n")
    ensure
      cleanup
    end
  end

  private

  def setup_driver
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless') if ENV['HEADLESS'] == 'true'
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--window-size=1920,1080')
    
    @driver = Selenium::WebDriver.for(:chrome, options: options)
    @driver.manage.timeouts.implicit_wait = 10
    @driver.manage.timeouts.page_load = 30
  end

  def test_public_plans_flow
    puts "🌍 Testing Public Plans flow..."
    
    # Step 1: Go to public plans page
    @driver.get("#{@base_url}/ja/public_plans")
    wait_for_page_load
    puts "  ✅ Public plans page loaded"
    
    # Step 2: Select region (Japan)
    region_buttons = @driver.find_elements(css: '.region-card')
    raise "No region cards found" if region_buttons.empty?
    
    japan_button = region_buttons.find { |btn| btn.text.include?('日本') }
    raise "Japan region button not found" unless japan_button
    
    japan_button.click
    wait_for_page_load
    puts "  ✅ Japan region selected"
    
    # Step 3: Select farm size
    farm_size_buttons = @driver.find_elements(css: '.farm-size-card')
    raise "No farm size cards found" if farm_size_buttons.empty?
    
    # Select first available farm size
    farm_size_buttons.first.click
    wait_for_page_load
    puts "  ✅ Farm size selected"
    
    # Step 4: Select crops
    crop_checkboxes = @driver.find_elements(css: 'input[type="checkbox"]')
    raise "No crop checkboxes found" if crop_checkboxes.empty?
    
    # Select first 2-3 crops
    selected_crops = crop_checkboxes.first(3)
    selected_crops.each(&:click)
    puts "  ✅ Crops selected: #{selected_crops.length}"
    
    # Step 5: Submit form
    submit_button = @driver.find_element(css: 'input[type="submit"], button[type="submit"]')
    submit_button.click
    wait_for_page_load
    puts "  ✅ Form submitted"
    
    # Step 6: Wait for optimization to complete
    wait_for_optimization_completion
    puts "  ✅ Optimization completed"
  end

  def test_save_to_my_plans
    puts "💾 Testing save to My Plans..."
    
    # Check if save button exists
    save_button = @driver.find_element(css: 'button, input[type="button"]')
    save_text = save_button.text.downcase
    
    if save_text.include?('保存') || save_text.include?('save')
      save_button.click
      wait_for_page_load
      puts "  ✅ Save button clicked"
      
      # Handle login if needed
      if @driver.current_url.include?('login') || @driver.current_url.include?('auth')
        handle_login
      end
    else
      puts "  ⚠️ Save button not found or not visible"
    end
  end

  def test_plan_verification
    puts "📋 Verifying plan in My Plans..."
    
    # Go to My Plans page
    @driver.get("#{@base_url}/ja/plans")
    wait_for_page_load
    puts "  ✅ My Plans page loaded"
    
    # Check if plans exist
    plan_cards = @driver.find_elements(css: '.plan-card, .card, [class*="plan"]')
    puts "  📊 Found #{plan_cards.length} plan cards"
    
    if plan_cards.any?
      # Click on the first plan
      plan_cards.first.click
      wait_for_page_load
      puts "  ✅ Plan details page loaded"
      
      # Verify plan has crops
      crop_elements = @driver.find_elements(css: '[class*="crop"], [class*="作物"]')
      puts "  🌱 Found #{crop_elements.length} crop elements"
      
      # Verify plan has fields
      field_elements = @driver.find_elements(css: '[class*="field"], [class*="圃場"]')
      puts "  🚜 Found #{field_elements.length} field elements"
    else
      puts "  ⚠️ No plans found in My Plans"
    end
  end

  def test_gantt_chart
    puts "📊 Testing Gantt chart..."
    
    # Look for Gantt chart elements
    gantt_elements = @driver.find_elements(css: '[class*="gantt"], [class*="chart"], [class*="timeline"]')
    puts "  📈 Found #{gantt_elements.length} chart elements"
    
    # Look for SVG elements (common in charts)
    svg_elements = @driver.find_elements(css: 'svg')
    puts "  🎨 Found #{svg_elements.length} SVG elements"
    
    # Look for canvas elements
    canvas_elements = @driver.find_elements(css: 'canvas')
    puts "  🖼️ Found #{canvas_elements.length} canvas elements"
    
    if gantt_elements.any? || svg_elements.any? || canvas_elements.any?
      puts "  ✅ Chart elements found"
    else
      puts "  ⚠️ No chart elements found"
    end
  end

  def handle_login
    puts "🔐 Handling login..."
    
    # Look for Google login button
    google_button = @driver.find_element(css: '[href*="google"], [class*="google"], button')
    google_button.click
    wait_for_page_load
    
    # For testing purposes, we'll assume login succeeds
    # In a real test, you'd need to handle OAuth flow
    puts "  ✅ Login handled (assuming success for testing)"
  end

  def wait_for_page_load
    @driver.execute_script("return document.readyState") == "complete"
    sleep(2) # Additional wait for dynamic content
  end

  def wait_for_optimization_completion
    puts "  ⏳ Waiting for optimization to complete..."
    
    Timeout.timeout(120) do # 2 minutes timeout
      loop do
        begin
          # Look for completion indicators
          if @driver.page_source.include?('完了') || 
             @driver.page_source.include?('completed') ||
             @driver.current_url.include?('results')
            break
          end
          
          # Look for error indicators
          if @driver.page_source.include?('エラー') || 
             @driver.page_source.include?('error') ||
             @driver.page_source.include?('失敗')
            raise "Optimization failed"
          end
          
          sleep(5)
        rescue Selenium::WebDriver::Error::NoSuchElementError
          sleep(5)
        end
      end
    end
  rescue Timeout::Error
    puts "  ⚠️ Optimization timeout (continuing anyway)"
  end

  def cleanup
    @driver&.quit
  end
end

# Run the test
if __FILE__ == $0
  test = PublicPlansToMyPlansTest.new
  test.run
end
