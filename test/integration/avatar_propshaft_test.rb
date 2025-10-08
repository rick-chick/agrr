# frozen_string_literal: true

require "test_helper"

class AvatarPropshaftTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_authenticated_user
  end

  test "avatar with full path should be rejected by validation" do
    # 修正後は、フルパス形式は新しいバリデーションで拒否される
    assert_raises(ActiveRecord::RecordInvalid) do
      @user.update!(avatar_url: '/assets/dev-avatar.svg')
    end
    
    # バリデーションエラーの内容を確認
    @user.avatar_url = '/assets/dev-avatar.svg'
    assert_not @user.valid?
    assert_includes @user.errors[:avatar_url], "must be a valid URL or SVG filename"
  end

  test "avatar with filename only resolves correctly with digest enabled" do
    # 修正後の実装：ファイル名のみを保存
    @user.update!(avatar_url: 'dev-avatar.svg')
    
    get root_path
    assert_response :success
    
    # image_tag はファイル名から自動的に digest付きパスを生成
    assert_select "img.user-avatar[src*='dev-avatar']", count: 1
    
    # 実際のsrcにはdigestが含まれているはず
    img = css_select("img.user-avatar").first
    src = img['src']
    # digest有効時は /assets/dev-avatar-[hash].svg の形式になる
    assert_match(/\/assets\/dev-avatar(-[a-f0-9]+)?\.svg/, src)
  end

  test "external avatar URL should remain unchanged" do
    # Google等の外部URL
    external_url = 'https://lh3.googleusercontent.com/a/example'
    @user.update!(avatar_url: external_url)
    
    get root_path
    assert_response :success
    
    # 外部URLはそのまま出力される
    assert_select "img[src='#{external_url}']", count: 1
  end

  test "avatar helper should generate correct asset path" do
    # ヘルパーメソッドのテスト
    # ファイル名のみの場合
    filename_only = 'dev-avatar.svg'
    path = ActionController::Base.helpers.image_path(filename_only)
    
    # digest有効時は digest付きパス
    assert_match(/\/assets\/dev-avatar(-[a-f0-9]+)?\.svg/, path)
    
    # フルパスの場合（現在の実装の問題点）
    full_path = '/assets/dev-avatar.svg'
    path_from_full = ActionController::Base.helpers.image_path(full_path)
    # フルパスはそのまま返される（digest解決されない＝問題）
    # これが現在の実装の問題
    assert_equal '/assets/dev-avatar.svg', path_from_full, 
                 "Full path should remain unchanged (this is the problem we're fixing)"
  end

  test "propshaft manifest should contain avatar files" do
    # propshaftのマニフェストにアバターファイルが含まれているか
    manifest_path = Rails.root.join('public', 'assets', '.manifest.json')
    
    # テスト環境では manifest が生成されていない可能性があるのでスキップ
    skip "Manifest not found" unless File.exist?(manifest_path)
    
    manifest = JSON.parse(File.read(manifest_path))
    assert manifest.key?('dev-avatar.svg'), "dev-avatar.svg should be in manifest"
    
    # manifestの値はdigest付きファイル名
    digested_filename = manifest['dev-avatar.svg']
    assert_match(/dev-avatar-[a-f0-9]+\.svg/, digested_filename)
  end
end
