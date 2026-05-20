require "test_helper"
require "database_cleaner/active_record"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ActionView::RecordIdentifier

  # システムテストではトランザクショナルテストを無効にする
  # （ブラウザとRailsサーバーが異なるプロセスでデータベースを共有するため）
  self.use_transactional_tests = false

  # Capybaraのパフォーマンス最適化
  Capybara.default_max_wait_time = 15 # システムテスト安定化のため15秒に延長（Angular hydration, JS描画, 非同期待機対応）
  Capybara.default_normalize_ws = true

  # Docker環境でリモートSeleniumを使用する場合
  Capybara.register_driver :local_headless_chrome do |app|
    chromedriver_path =
      ENV["CHROMEDRIVER_PATH"].presence ||
      %w[/usr/lib/chromium/chromedriver /usr/bin/chromedriver].find { |p| File.exist?(p) }

    unless chromedriver_path
      raise "Chromedriverが見つかりません。CHROMEDRIVER_PATH 環境変数で明示的に指定してください。"
    end

    chrome_service = Selenium::WebDriver::Chrome::Service.new(path: chromedriver_path)

    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--headless=new")
    options.add_argument("--disable-extensions")
    options.add_argument("--disable-logging")
    options.add_argument("--disable-software-rasterizer")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--window-size=1400,1400")
    options.add_argument("--disable-web-security")
    options.add_argument("--allow-running-insecure-content")
    # ロケール検出を ja に固定する。CI ブラウザ既定の Accept-Language（en-US 等）が
    # アプリのロケール検出に漏れ込み、システムテストが非決定的になるのを防ぐ。
    options.add_argument("--lang=ja")
    options.add_preference("intl.accept_languages", "ja")

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
    app_js_path = Rails.root.join("app", "assets", "builds", "application.js")
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
      "provider" => "google_oauth2",
      "uid" => "dev_user_001",
      "info" => {
        "email" => "developer@agrr.dev",
        "name" => "開発者",
        "image" => "dev-avatar.svg"
      }
    })
  end

  # システムテスト用のログイン&訪問ヘルパー
  def login_and_visit(url)
    visit root_path(locale: :ja)
    page.driver.browser.manage.add_cookie(
      name: "session_id",
      value: @session.session_id,
      path: "/"
    )
    visit url
  end

  # Cookie consent acceptヘルパー
  def accept_cookie_consent
    if has_selector?(".cookie-consent-banner", visible: true, wait: 5)
      find("button.btn-primary", text: /同意/).click
    end
  end

  # Cookie consent dismissヘルパー
  def dismiss_cookie_consent
    if has_selector?(".cookie-consent-banner", visible: true, wait: 5)
      find("button.btn-primary", text: /同意/).click
    end
  end

  # localStorageにCookie同意ステータスを直接設定する（UIクリックのタイミング問題を回避）
  def set_cookie_consent_granted
    page.execute_script("localStorage.setItem('cookieConsentStatus', 'granted')")
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
      name: "session_id",
      value: session.session_id,
      path: "/"
    )

    # APIキーをLocalStorageに設定
    visit root_path
    page.execute_script("localStorage.setItem('agrr_api_key', '#{user.api_key}')")

    # Cookie同意をlocalStorageに直接設定（バナーによるクリック妨害を全システムテストで回避）
    set_cookie_consent_granted

    # デバッグ用にコンソールログを表示
    page.execute_script("console.log('API Key set')")

    # ページをリロードして認証状態を反映
    visit root_path
  end
end
