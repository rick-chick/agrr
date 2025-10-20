require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ActionView::RecordIdentifier
  
  # システムテストではトランザクショナルテストを無効にする
  # （ブラウザとRailsサーバーが異なるプロセスでデータベースを共有するため）
  self.use_transactional_tests = false
  
  # Docker環境でSeleniumを使用する場合
  if ENV['SELENIUM_HOST']
    Capybara.server_host = '0.0.0.0'
    Capybara.server_port = 3001
    
    # Docker環境ではホスト名を取得
    hostname = ENV['HOSTNAME'] || `hostname`.strip
    Capybara.app_host = "http://#{hostname}:#{Capybara.server_port}"
    
    Capybara.register_driver :selenium_remote_chrome do |app|
      url = "http://#{ENV['SELENIUM_HOST']}:#{ENV['SELENIUM_PORT'] || '4444'}/wd/hub"
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument('--headless=new')
      options.add_argument('--no-sandbox')
      options.add_argument('--disable-dev-shm-usage')
      options.add_argument('--disable-gpu')
      options.add_argument('--window-size=1400,1400')
      
      Capybara::Selenium::Driver.new(
        app,
        browser: :remote,
        url: url,
        options: options
      )
    end
    
    driven_by :selenium_remote_chrome
  else
    # ローカル環境
    driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]
  end

  # システムテスト用の認証ヘルパー
  def setup
    setup_omniauth_test_mode
    
    # WALモードを有効にしてデータベース共有を可能にする
    ActiveRecord::Base.connection.execute("PRAGMA journal_mode = WAL")
    ActiveRecord::Base.connection.execute("PRAGMA synchronous = NORMAL")
  end
  
  # テスト後のクリーンアップ（トランザクションが無効なため手動でクリーンアップ）
  def teardown
    # Capybaraのセッションをリセット
    Capybara.reset_sessions!
    Capybara.use_default_driver
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



