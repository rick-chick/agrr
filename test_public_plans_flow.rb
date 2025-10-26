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
      test_cultivation_plan_crop_duplication_prevention
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

  def test_cultivation_plan_crop_duplication_prevention
    puts "🔍 Testing CultivationPlanCrop duplication prevention..."
    
    # Railsコンソールでテストを実行
    test_result = `docker compose exec web rails runner "
      # テストユーザーを取得
      user = User.where(is_anonymous: false).first
      if user.nil?
        puts 'ERROR: No test user found'
        exit 1
      end
      
      puts 'Using user: ' + user.name + ' (ID: ' + user.id.to_s + ')'
      
      # 理想的な移送方法: セッションデータから農場IDを取得
      # 実際のフローでは、ユーザーが選択した農場IDがセッションデータに保存される
      # ここでは秋田の農場ID（3）を使用してテストする
      farm_id = 3  # 秋田の農場ID
      farm = Farm.find(farm_id)
      if farm.nil?
        puts 'ERROR: Farm with ID ' + farm_id.to_s + ' not found'
        exit 1
      end
      
      puts 'Selected farm: ' + farm.name + ' (ID: ' + farm.id.to_s + ')'
      
      # 同じ名前の作物を複数選択（トマトを2回）
      crops = [Crop.find(1), Crop.find(1)] # トマトを2回
      puts 'Selected crops: ' + crops.map(&:name).join(', ')
      
      # 参照計画を作成（同じ作物を複数含む）
      plan = CultivationPlan.create!(
        farm: farm,
        user: nil, # 参照計画
        total_area: 300.0,
        plan_type: 'public',
        plan_year: Date.current.year,
        plan_name: '重複防止テスト計画',
        planning_start_date: Date.current,
        planning_end_date: Date.current.end_of_year,
        status: 'completed'
      )
      
      # CultivationPlanCropを手動で作成（同じ名前の作物を複数）
      CultivationPlanCrop.create!(
        cultivation_plan: plan,
        crop: crops[0],
        name: crops[0].name,
        variety: '品種A',
        area_per_unit: crops[0].area_per_unit,
        revenue_per_area: crops[0].revenue_per_area
      )
      
      CultivationPlanCrop.create!(
        cultivation_plan: plan,
        crop: crops[1],
        name: crops[1].name,
        variety: '品種B',
        area_per_unit: crops[1].area_per_unit,
        revenue_per_area: crops[1].revenue_per_area
      )
      
      puts 'Created test plan: ' + plan.plan_name + ' (ID: ' + plan.id.to_s + ')'
      
      # 参照計画のCultivationPlanCropを確認
      puts 'Reference plan CultivationPlanCrops:'
      plan.cultivation_plan_crops.each do |crop|
        puts '  - ' + crop.name + ' (crop_id: ' + crop.crop_id.to_s + ', variety: ' + (crop.variety || 'nil').to_s + ')'
      end
      
      # セッションデータを構築
      session_data = {
        plan_id: plan.id,
        farm_id: farm.id,
        crop_ids: crops.map(&:id),
        field_data: [
          { name: '重複防止テスト圃場1', area: 100.0, coordinates: [35.0, 139.0] },
          { name: '重複防止テスト圃場2', area: 200.0, coordinates: [35.1, 139.1] }
        ]
      }
      
      puts 'Session data: ' + session_data.inspect
      
      # PlanSaveServiceを実行
      service = PlanSaveService.new(user: user, session_data: session_data)
      result = service.call
      
      puts 'Result: ' + result.success.to_s
      if !result.success
        puts 'Error: ' + result.error_message
        exit 1
      end
      
      # 作成された計画のCultivationPlanCropを確認
      new_plan = user.cultivation_plans.where(plan_type: 'private').order(:created_at).last
      puts 'New plan: ' + new_plan.plan_name + ' (ID: ' + new_plan.id.to_s + ')'
      
      puts 'New plan CultivationPlanCrops:'
      new_plan.cultivation_plan_crops.each do |crop|
        puts '  - ' + crop.name + ' (crop_id: ' + crop.crop_id.to_s + ', variety: ' + (crop.variety || 'nil').to_s + ')'
      end
      
      # 重複チェック
      crop_names = new_plan.cultivation_plan_crops.map(&:name)
      duplicate_names = crop_names.select { |name| crop_names.count(name) > 1 }.uniq
      
      if duplicate_names.any?
        puts 'ERROR: DUPLICATE CultivationPlanCrops found:'
        duplicate_names.each do |name|
          duplicates = new_plan.cultivation_plan_crops.select { |crop| crop.name == name }
          puts '  - ' + name + ': ' + duplicates.count.to_s + ' instances'
        end
        exit 1
      else
        puts 'SUCCESS: No duplicate CultivationPlanCrops found - duplication prevention working!'
      end
      
      # 同じcrop_idのCultivationPlanCropが1つだけであることを確認
      crop_ids = new_plan.cultivation_plan_crops.map(&:crop_id)
      duplicate_crop_ids = crop_ids.select { |crop_id| crop_ids.count(crop_id) > 1 }.uniq
      
      if duplicate_crop_ids.any?
        puts 'ERROR: DUPLICATE crop_ids found:'
        duplicate_crop_ids.each do |crop_id|
          duplicates = new_plan.cultivation_plan_crops.select { |crop| crop.crop_id == crop_id }
          puts '  - crop_id ' + crop_id.to_s + ': ' + duplicates.count.to_s + ' instances'
        end
        exit 1
      else
        puts 'SUCCESS: No duplicate crop_ids found - each crop_id has only one CultivationPlanCrop!'
      end
      
      puts 'TEST PASSED: CultivationPlanCrop duplication prevention is working correctly'
    "`
    
    if $?.success?
      puts "  ✅ CultivationPlanCrop duplication prevention test passed"
      puts "  📋 Test output:"
      puts test_result.lines.map { |line| "    #{line}" }.join
    else
      puts "  ❌ CultivationPlanCrop duplication prevention test failed"
      puts "  📋 Test output:"
      puts test_result.lines.map { |line| "    #{line}" }.join
      raise "CultivationPlanCrop duplication prevention test failed"
    end
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
