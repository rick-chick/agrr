require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ActionView::RecordIdentifier
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
  end

  def setup_omniauth_test_mode
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
      'provider' => 'google_oauth2',
      'uid' => 'google_12345678',
      'info' => {
        'email' => 'test@example.com',
        'name' => 'Test User',
        'image' => 'https://example.com/avatar.jpg'
      }
    })
  end
end



