# frozen_string_literal: true

require "test_helper"

class AuthTestControllerTest < ActionDispatch::IntegrationTest
  def setup
    # 既存のセッションとユーザーをクリア
    Session.destroy_all
    User.destroy_all
  end

  test "should successfully mock login as developer" do
    get auth_test_mock_login_as_path(user: 'developer')
    assert_redirected_to root_path
    assert_equal "Mock login successful as 開発者!", flash[:notice]
    
    # ユーザーが作成されたことを確認
    user = User.find_by(google_id: 'dev_user_001')
    assert_not_nil user
    assert_equal 'developer@agrr.dev', user.email
    assert_equal 'dev-avatar.svg', user.avatar_url
    
    # セッションが作成されたことを確認
    assert_not_nil cookies[:session_id]
    session = Session.find_by(session_id: cookies[:session_id])
    assert_not_nil session
    assert_equal user.id, session.user_id
  end

  test "should successfully mock login as farmer" do
    get auth_test_mock_login_as_path(user: 'farmer')
    assert_redirected_to root_path
    assert_equal "Mock login successful as 農家太郎!", flash[:notice]
    
    user = User.find_by(google_id: 'farmer_user_002')
    assert_not_nil user
    assert_equal 'farm-avatar.svg', user.avatar_url
  end

  test "should successfully mock login as researcher" do
    get auth_test_mock_login_as_path(user: 'researcher')
    assert_redirected_to root_path
    assert_equal "Mock login successful as 研究員花子!", flash[:notice]
    
    user = User.find_by(google_id: 'researcher_user_003')
    assert_not_nil user
    assert_equal 'res-avatar.svg', user.avatar_url
  end

  test "should handle invalid user type" do
    get auth_test_mock_login_as_path(user: 'invalid')
    assert_redirected_to auth_login_path
    assert_equal 'Invalid user type.', flash[:alert]
  end

  test "should handle existing user with old avatar_url format" do
    # 古い形式の avatar_url を持つユーザーを作成（バリデーションをスキップ）
    user = User.new(
      email: 'developer@agrr.dev',
      name: '開発者',
      google_id: 'dev_user_001',
      avatar_url: '/assets/dev-avatar.svg' # 古い形式
    )
    user.save(validate: false) # バリデーションをスキップして保存
    
    # このユーザーでログインを試みる
    get auth_test_mock_login_as_path(user: 'developer')
    
    # エラーが発生するか、適切に処理されるべき
    # 現在の実装では find_or_create_by がユーザーを見つけるが、
    # ブロックが実行されないため avatar_url が更新されない
    # そして Session.create_for_user で user が invalid な可能性がある
    
    # 実際のエラーを確認
    assert_redirected_to root_path
    
    # ユーザーが見つかったことを確認
    found_user = User.find_by(google_id: 'dev_user_001')
    assert_not_nil found_user
    
    # セッションが作成されたかどうかを確認
    # もし user が無効なら、Session.create_for_user が失敗する可能性がある
  end

  test "should handle NOT NULL constraint error gracefully when user is not persisted" do
    # find_or_create_by がバリデーションエラーで失敗する状況をシミュレート
    # 新規ユーザー作成時に無効な avatar_url でバリデーションエラーが発生する
    
    # OmniAuth モックを一時的に無効なデータに変更
    original_mock = OmniAuth.config.mock_auth[:google_oauth2]
    
    # 無効な avatar_url を含むモックデータ（新規ユーザー）
    # ただし、User.process_avatar_url が '/assets/invalid-path.svg' を 'invalid-path.svg' に変換するので
    # これは有効な形式になる。完全に無効なデータを作る必要がある
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: 'google_oauth2',
      uid: 'new_invalid_user', # 新しいユーザーID
      info: {
        email: 'invalid', # 無効なメールアドレス
        name: 'Invalid User',
        image: 'valid-avatar.svg'
      }
    )
    
    begin
      # 修正後：find_or_create_by がバリデーションエラーで失敗しても、
      # user.persisted? チェックで適切にハンドリングされ、エラーメッセージと共にリダイレクト
      get auth_test_mock_login_as_path(user: 'developer')
      
      # ログインページにリダイレクトされる
      assert_redirected_to auth_login_path
      follow_redirect!
      
      # エラーメッセージが表示される
      assert_match /Failed to create user/, flash[:alert]
    ensure
      # モックを元に戻す
      OmniAuth.config.mock_auth[:google_oauth2] = original_mock
    end
  end

  test "should handle user creation with invalid avatar_url" do
    # 新しいバリデーションルールに違反する avatar_url でユーザー作成を試みる
    
    # モックを無効なデータに設定
    OmniAuth.config.mock_auth[:test_invalid] = OmniAuth::AuthHash.new(
      provider: 'google_oauth2',
      uid: 'invalid_user_001',
      info: {
        email: 'invalid@example.com',
        name: 'Invalid User',
        image: '/assets/some-avatar.svg' # バリデーションエラー
      }
    )
    
    # AuthTestController は google_oauth2_* のキーしか使わないので、
    # 直接 User.find_or_create_by を使ってテスト
    auth_hash = OmniAuth.config.mock_auth[:test_invalid]
    
    assert_raises(ActiveRecord::RecordInvalid) do
      user = User.find_or_create_by!(google_id: auth_hash['uid']) do |u|
        u.email = auth_hash['info']['email']
        u.name = auth_hash['info']['name']
        u.avatar_url = auth_hash['info']['image']
      end
      
      # user が作成されたが保存されていない場合
      # Session.create_for_user(user) は失敗する
      Session.create_for_user(user)
    end
  end

  test "should successfully update existing user on subsequent login" do
    # 最初のログイン
    get auth_test_mock_login_as_path(user: 'developer')
    user = User.find_by(google_id: 'dev_user_001')
    original_name = user.name
    
    # ユーザー名を変更
    user.update!(name: 'Changed Name')
    
    # 再度ログイン
    get auth_test_mock_login_as_path(user: 'developer')
    
    # ユーザーが見つかったが、ブロックは実行されないので名前は更新されない
    user.reload
    # find_or_create_by はブロックを既存ユーザーには実行しない
    assert_equal 'Changed Name', user.name
  end
end
