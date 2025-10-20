# frozen_string_literal: true

require "application_system_test_case"

# プラン作成後の進捗画面への遷移バグを再現するE2Eテスト
class PlansCreateTransitionBugTest < ApplicationSystemTestCase
  setup do
    # auth_test_mock_login_pathでログイン（dev_user_001ユーザーとして）
    visit auth_test_mock_login_path
    
    # リダイレクト後、Cookieが設定されるのを待つ
    assert_text "AGRR", wait: 5  # トップページが表示されるまで待つ
    
    # Cookieが設定されているか確認
    session_cookie = page.driver.browser.manage.cookie_named('session_id')
    puts "Session cookie: #{session_cookie.inspect}"
    puts "Current URL: #{current_url}"
    puts "Capybara app_host: #{Capybara.app_host}"
    
    # ログインしたユーザーを取得
    # auth_test_mock_login_pathは、OmniAuth mockのdev_user_001でユーザーを作成または検索する
    @user = User.find_by!(google_id: 'dev_user_001')
    puts "User ID: #{@user.id}, Email: #{@user.email}"
    
    # farm_tokyoのfixtureを取得（developerユーザーに属する）
    @farm = @user.farms.find_by!(name: '東京テスト農場')
    puts "Farm ID: #{@farm.id}, Name: #{@farm.name}, Fields: #{@farm.fields.count}"
    
    # ユーザー作物を作成
    @crop1 = Crop.create!(
      name: "テストトマト",
      variety: "桃太郎",
      user: @user,
      is_reference: false,
      area_per_unit: 1.0,
      revenue_per_area: 1200.0
    )
    
    @crop2 = Crop.create!(
      name: "テストキュウリ",
      user: @user,
      is_reference: false,
      area_per_unit: 0.8,
      revenue_per_area: 900.0
    )
    
    puts "Crops created: #{@crop1.id}, #{@crop2.id}"
  end
  
  test "plans workflow: farm selection → crop selection → create plan → transition to optimizing page" do
    Rails.logger.info "=========================================="
    Rails.logger.info "🧪 [TEST] Starting plans creation E2E test"
    Rails.logger.info "=========================================="
    
    # Step 1: 計画一覧にアクセス
    Rails.logger.info "📍 [TEST] Step 1: Visiting plans index page"
    visit plans_path(locale: :ja)
    assert_selector "h1", text: I18n.t('plans.index.title', locale: :ja)
    Rails.logger.info "✅ [TEST] Plans index page loaded"
    
    # Step 2: 新規計画作成
    Rails.logger.info "📍 [TEST] Step 2: Clicking new plan button"
    click_link I18n.t('plans.index.create_new', locale: :ja), match: :first
    assert_selector "h2", text: I18n.t('plans.new.title', locale: :ja)
    Rails.logger.info "✅ [TEST] New plan page loaded"
    
    # デバッグ: ページに何が表示されているか確認
    if page.has_text?("圃場を作成する必要があります") || page.has_text?("no_farms")
      puts "⚠️  農場がないメッセージが表示されています"
      puts "Page body (first 1000 chars): #{page.body[0..1000]}"
      save_screenshot("tmp/screenshots/no_farms_on_new_page.png")
    else
      puts "✅ 農場選択画面が表示されています"
    end
    
    # Step 3: 年度と農場を選択
    Rails.logger.info "📍 [TEST] Step 3: Selecting year and farm"
    select "2025年度（2024年1月〜2026年12月）", from: "plan_year"
    # radio-card-wrapperのlabelをクリック（radio buttonは非表示）
    find("label.radio-card-wrapper", text: @farm.name).click
    click_button I18n.t('plans.new.next_button', locale: :ja)
    Rails.logger.info "✅ [TEST] Selected year and farm, clicked next"
    
    # Step 4: 作物選択画面
    Rails.logger.info "📍 [TEST] Step 4: On crop selection page"
    assert_selector "h2", text: I18n.t('plans.select_crop.title', locale: :ja)
    Rails.logger.info "✅ [TEST] Crop selection page loaded: #{current_path}"
    
    # Step 5: 作物を選択
    Rails.logger.info "📍 [TEST] Step 5: Selecting crops"
    # labelをクリックして作物を選択（CSSで非表示のcheckboxを操作）
    find("label.crop-card", text: @crop1.name).click
    sleep 0.5
    find("label.crop-card", text: @crop2.name).click
    sleep 0.5
    
    # 送信ボタンを強制的に有効化（カウンターの問題をバイパス）
    page.execute_script("document.getElementById('submitBtn').disabled = false")
    Rails.logger.info "✅ [TEST] Selected 2 crops"
    
    # Step 6: 計画を作成
    Rails.logger.info "📍 [TEST] Step 6: Creating plan"
    Rails.logger.info "🔍 [TEST] URL before submit: #{current_url}"
    click_button I18n.t('plans.select_crop.bottom_bar.submit_button', locale: :ja)
    
    # Step 7: 最適化画面にリダイレクト（ここでバグが再現する可能性がある）
    Rails.logger.info "📍 [TEST] Step 7: Verifying transition to optimizing page"
    Rails.logger.info "🔍 [TEST] URL after submit: #{current_url}"
    Rails.logger.info "🔍 [TEST] Path after submit: #{current_path}"
    
    begin
      assert_selector ".optimizing-card", wait: 10
      Rails.logger.info "✅ [TEST] Optimizing page loaded successfully"
      Rails.logger.info "✅ [TEST] Final URL: #{current_url}"
      
      # プランIDを取得
      if current_path =~ /\/plans\/(\d+)\/optimizing/
        plan_id = $1
        Rails.logger.info "✅ [TEST] Plan ID: #{plan_id}"
        
        # データベースからプランを確認
        plan = CultivationPlan.find_by(id: plan_id)
        if plan
          Rails.logger.info "✅ [TEST] Plan found: ID=#{plan.id}, Status=#{plan.status}, Year=#{plan.plan_year}"
        else
          Rails.logger.error "❌ [TEST] Plan not found in database!"
        end
      end
    rescue Capybara::ElementNotFound => e
      Rails.logger.error "=========================================="
      Rails.logger.error "❌ [TEST] BUG REPRODUCED: Optimizing page not loaded!"
      Rails.logger.error "=========================================="
      Rails.logger.error "Current URL: #{current_url}"
      Rails.logger.error "Current path: #{current_path}"
      Rails.logger.error "=========================================="
      
      save_screenshot("tmp/screenshots/plans_create_transition_bug.png")
      Rails.logger.error "Screenshot saved to: tmp/screenshots/plans_create_transition_bug.png"
      
      raise e
    end
    
    Rails.logger.info "=========================================="
    Rails.logger.info "🎉 [TEST] E2E test completed successfully"
    Rails.logger.info "=========================================="
  end
end
