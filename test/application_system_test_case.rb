require "test_helper"
require "database_cleaner/active_record"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ActionView::RecordIdentifier
  
  # システムテストではトランザクショナルテストを無効にする
  # （ブラウザとRailsサーバーが異なるプロセスでデータベースを共有するため）
  self.use_transactional_tests = false
  
  # Capybaraのパフォーマンス最適化
  Capybara.default_max_wait_time = 5 # デフォルトは2秒、必要に応じて調整
  Capybara.default_normalize_ws = true
  
  # Docker環境でリモートSeleniumを使用する場合
  Capybara.register_driver :local_headless_chrome do |app|
    chromedriver_path =
      ENV['CHROMEDRIVER_PATH'].presence ||
      %w[/usr/lib/chromium/chromedriver /usr/bin/chromedriver].find { |p| File.exist?(p) }

    unless chromedriver_path
      raise "Chromedriverが見つかりません。CHROMEDRIVER_PATH 環境変数で明示的に指定してください。"
    end

    chrome_service = Selenium::WebDriver::Chrome::Service.new(path: chromedriver_path)

    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless=new')
    options.add_argument('--disable-extensions')
    options.add_argument('--disable-logging')
    options.add_argument('--disable-software-rasterizer')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--window-size=1400,1400')

    Capybara::Selenium::Driver.new(
      app,
      browser: :chrome,
      options: options,
      service: chrome_service
    )
  end

  driven_by :local_headless_chrome

  # DatabaseCleanerの設定
  def before_setup
    # システムテスト前にapplication.jsがビルドされているか確認
    ensure_application_js_built
    
    DatabaseCleaner[:active_record].strategy = :truncation
    DatabaseCleaner[:active_record].start
    super
  end
  
  # application.jsがビルドされているか確認し、なければダミーファイルを作成
  def ensure_application_js_built
    app_js_path = Rails.root.join('app', 'assets', 'builds', 'application.js')
    unless File.exist?(app_js_path)
      Rails.logger.warn "[System Test] ⚠️ application.js not found at #{app_js_path}"
      Rails.logger.warn "[System Test] Creating dummy application.js for test environment (Propshaft requires this)"
      
      # Propshaftが存在しないアセットに対してエラーを発生させるため、ダミーファイルを作成
      FileUtils.mkdir_p(app_js_path.dirname)
      File.write(app_js_path, "// Dummy application.js for test environment\n// This file is auto-generated when application.js is not built\n")
      
      Rails.logger.info "[System Test] ✓ Created dummy application.js"
    end
  end

  # システムテスト用の認証ヘルパー
  def setup
    setup_omniauth_test_mode
    
    # WALモードを有効にしてデータベース共有を可能にする
    ActiveRecord::Base.connection.execute("PRAGMA journal_mode = WAL")
    ActiveRecord::Base.connection.execute("PRAGMA synchronous = NORMAL")
  end
  
  # テスト後のクリーンアップ（高速化）
  def teardown
    # Capybaraのセッションをリセット
    Capybara.reset_sessions!
    Capybara.use_default_driver
  ensure
    # DatabaseCleanerでDBをクリーンアップ
    DatabaseCleaner[:active_record].clean
  end

  def setup_omniauth_test_mode
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
      'provider' => 'google_oauth2',
      'uid' => 'dev_user_001',
      'info' => {
        'email' => 'developer@agrr.dev',
        'name' => '開発者',
        'image' => 'dev-avatar.svg'
      }
    })
  end
  
  # システムテスト用のログインヘルパー
  def login_as_system_user(user)
    # セッションを作成
    session = Session.create_for_user(user)
    
    # データをディスクに書き込む
    session.save!
    user.reload
    
    # まずトップページにアクセス（Cookieを設定するためのドメインを確立）
    visit root_path
    
    # Capybaraを使ってCookieを設定
    page.driver.browser.manage.add_cookie(
      name: 'session_id',
      value: session.session_id,
      path: '/'
    )
    
    # ページをリロードして認証状態を反映
    visit root_path
  end
end



