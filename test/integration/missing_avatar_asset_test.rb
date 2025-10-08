# frozen_string_literal: true

require "test_helper"

class MissingAvatarAssetTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_authenticated_user
  end

  test "should successfully display farm avatar now that file exists" do
    # farm-avatar.svg が作成されたので正常に表示できる
    @user.update!(avatar_url: 'farm-avatar.svg')
    
    # エラーなく表示できる
    get root_path
    assert_response :success
    assert_select "img.user-avatar[src*='farm-avatar']"
  end

  test "should raise MissingAssetError when non-existent avatar is used" do
    # 存在しないアバターファイル名
    @user.update!(avatar_url: 'non-existent-avatar.svg')
    
    error = assert_raises(ActionView::Template::Error) do
      get root_path
    end
    
    assert_match /non-existent-avatar\.svg/, error.message
    assert_match /was not found in the load path/, error.message
  end

  test "should successfully display existing avatar files" do
    # 存在するファイル: dev-avatar.svg, farm-avatar.svg, res-avatar.svg
    existing_avatars = ['dev-avatar.svg', 'farm-avatar.svg', 'res-avatar.svg']
    
    existing_avatars.each do |avatar|
      @user.update!(avatar_url: avatar)
      
      # エラーなく表示できる
      get root_path
      assert_response :success
      assert_select "img.user-avatar[src*='#{avatar.split('.').first}']"
    end
  end

  test "should verify all required avatar files now exist" do
    # OmniAuth設定で使用されているアバター
    required_avatars = [
      'dev-avatar.svg',    # developer
      'farm-avatar.svg',   # farmer
      'res-avatar.svg'     # researcher
    ]
    
    # 実際に存在するファイルを確認
    existing_files = Dir.glob(Rails.root.join('app', 'assets', 'images', '*-avatar.svg'))
                        .map { |f| File.basename(f) }
    
    # 全ての必要なアバターが存在することを確認
    required_avatars.each do |avatar|
      assert_includes existing_files, avatar,
                      "#{avatar} should exist in app/assets/images/"
    end
  end

  test "should successfully display farmer avatar on home page" do
    # OmniAuthのfarmerモックデータを使ってユーザーを作成
    farmer_user = User.create!(
      email: 'farmer@agrr.dev',
      name: '農家太郎',
      google_id: 'farmer_user_002',
      avatar_url: 'farm-avatar.svg' # 今は存在する
    )
    
    # このユーザーでログイン
    session = Session.create_for_user(farmer_user)
    cookies[:session_id] = session.session_id
    
    # ホームページにアクセス -> 正常に表示
    get root_path
    assert_response :success
    
    # farm-avatarが表示されていることを確認
    assert_select "img.user-avatar[src*='farm-avatar']"
    assert_select "span", text: '農家太郎'
  end

  test "should verify no avatar files are missing" do
    # データベース内のユーザーが使用しているアバターを確認
    User.destroy_all
    
    # 各種ユーザーを作成
    users = [
      { email: 'dev@example.com', google_id: 'dev1', avatar_url: 'dev-avatar.svg' },
      { email: 'farmer@example.com', google_id: 'farmer1', avatar_url: 'farm-avatar.svg' },
      { email: 'res@example.com', google_id: 'res1', avatar_url: 'res-avatar.svg' }
    ]
    
    users.each do |user_data|
      User.create!(
        email: user_data[:email],
        name: 'Test User',
        google_id: user_data[:google_id],
        avatar_url: user_data[:avatar_url]
      )
    end
    
    # 使用されているローカルアバターの一覧
    local_avatars = User.where("avatar_url LIKE '%.svg'")
                       .where.not("avatar_url LIKE 'http%'")
                       .pluck(:avatar_url)
                       .uniq
    
    # farm-avatar.svg が使用されていることを確認
    assert_includes local_avatars, 'farm-avatar.svg'
    
    # 実際に存在するファイルと比較
    existing_files = Dir.glob(Rails.root.join('app', 'assets', 'images', '*-avatar.svg'))
                        .map { |f| File.basename(f) }
    
    missing_avatars = local_avatars - existing_files
    
    # 不足しているファイルがないことを確認
    assert_empty missing_avatars,
                 "All avatar files should exist. Missing: #{missing_avatars.join(', ')}"
  end
end
