# frozen_string_literal: true

require "test_helper"

class PlaceholderErrorReproductionTest < ActionDispatch::IntegrationTest
  def setup
    # 外部プレースホルダー画像を使用するユーザーを作成（エラー再現用）
    @user_with_external_avatar = User.create!(
      email: 'external@example.com',
      name: 'External Avatar User',
      google_id: "google_#{SecureRandom.hex(8)}",
      avatar_url: 'https://via.placeholder.com/50x50.png?text=RES'
    )
    
    # セッションを作成してユーザーを認証
    @session = Session.create_for_user(@user_with_external_avatar)
    cookies[:session_id] = @session.session_id
  end

  test "should reproduce ERR_NAME_NOT_RESOLVED error with external placeholder" do
    # フィールドページにアクセス
    get fields_path
    assert_response :success
    
    # 外部プレースホルダー画像が使用されていることを確認
    assert_select "img[src='https://via.placeholder.com/50x50.png?text=RES']", count: 1
    assert_match /via\.placeholder\.com/, response.body, "External placeholder image should be present"
    
    # ブラウザでこの画像を読み込もうとすると ERR_NAME_NOT_RESOLVED エラーが発生する
    # このテストでは、HTMLにその画像タグが含まれていることを確認
    assert_match /50x50\.png\?text=RES/, response.body, "Placeholder image URL should be present"
  end

  test "should reproduce error on new field page" do
    get new_field_path
    assert_response :success
    
    # 外部プレースホルダー画像が使用されていることを確認
    assert_select "img[src='https://via.placeholder.com/50x50.png?text=RES']", count: 1
    assert_match /via\.placeholder\.com/, response.body, "External placeholder image should be present"
  end

  test "should reproduce error on home page" do
    get root_path
    assert_response :success
    
    # 外部プレースホルダー画像が使用されていることを確認
    assert_select "img[src='https://via.placeholder.com/50x50.png?text=RES']", count: 1
    assert_match /via\.placeholder\.com/, response.body, "External placeholder image should be present"
  end

  test "should fail to load external placeholder image" do
    # 外部プレースホルダー画像への直接アクセスをテスト
    # これは実際には失敗するはず（ERR_NAME_NOT_RESOLVED）
    begin
      response = Net::HTTP.get_response(URI('https://via.placeholder.com/50x50.png?text=RES'))
      flunk "External placeholder should not be accessible"
    rescue => e
      # 期待されるエラー: DNS解決エラーまたはネットワークエラー
      assert_includes ["SocketError", "Net::OpenTimeout", "Errno::ETIMEDOUT", "OpenSSL::SSL::SSLError", "Socket::ResolutionError"], e.class.name
    end
  end

  test "should contain external placeholder references in HTML" do
    # 複数のページで外部プレースホルダー参照を確認
    pages_to_test = [fields_path, new_field_path, root_path]
    
    pages_to_test.each do |path|
      get path
      assert_response :success
      
      # 外部プレースホルダー参照が含まれていることを確認
      assert_match /via\.placeholder\.com/, response.body, "External placeholder reference should be in #{path}"
      assert_match /50x50\.png\?text=RES/, response.body, "Specific placeholder URL should be in #{path}"
    end
  end

  test "should demonstrate browser console error scenario" do
    get fields_path
    assert_response :success
    
    # ブラウザでこのHTMLを表示すると、以下のエラーが発生することをシミュレート:
    # "GET https://via.placeholder.com/50x50.png?text=RES net::ERR_NAME_NOT_RESOLVED"
    
    # HTMLに問題のある画像タグが含まれていることを確認
    assert_match /<img[^>]*src="https:\/\/via\.placeholder\.com\/50x50\.png\?text=RES"[^>]*>/, response.body, "Problematic image tag should be present"
    
    # ユーザー名も表示されていることを確認
    assert_match /External Avatar User/, response.body, "User name should be displayed"
  end

  test "should show error in browser console when loading page" do
    # このテストは、実際のブラウザでのエラー再現を示す
    get fields_path
    assert_response :success
    
    # 以下のHTMLが生成されることを確認:
    # <img src="https://via.placeholder.com/50x50.png?text=RES" alt="User Avatar" class="user-avatar">
    # 
    # ブラウザでこのページを開くと、コンソールに以下のエラーが表示される:
    # "GET https://via.placeholder.com/50x50.png?text=RES net::ERR_NAME_NOT_RESOLVED"
    
    assert_select "img.user-avatar[src='https://via.placeholder.com/50x50.png?text=RES']", count: 1
    assert_select "img[alt='User Avatar']", count: 1
  end

  test "should demonstrate fix by updating to local avatar" do
    # 修正をシミュレート: 外部プレースホルダーをローカルSVGに変更
    @user_with_external_avatar.update!(avatar_url: 'res-avatar.svg')
    
    get fields_path
    assert_response :success
    
    # 修正後: 外部プレースホルダー参照が消え、ローカルSVGが使用される
    assert_no_match /via\.placeholder\.com/, response.body, "External placeholder should be removed after fix"
    assert_select "img.user-avatar[src*='res-avatar']", count: 1
    
    # ローカルSVGファイルがアクセス可能であることを確認（digest付きパスで）
    avatar_path = ActionController::Base.helpers.image_path('res-avatar.svg')
    get avatar_path
    assert_response :success
    assert_equal "image/svg+xml", response.content_type
  end
end
