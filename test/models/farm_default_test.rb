# frozen_string_literal: true

require "test_helper"

class FarmDefaultTest < ActiveSupport::TestCase
  def setup
    # アノニマスユーザーを確実に作成
    User.instance_variable_set(:@anonymous_user, nil)
    @anonymous_user = User.anonymous_user
    @regular_user = users(:one)
    
    # 既存のデフォルト農場を削除（テスト用）
    Farm.where(is_default: true).destroy_all
  end

  test "should create default farm" do
    farm = Farm.create_default_farm!
    
    assert farm.persisted?
    assert farm.is_default
    assert_equal "デフォルト農場", farm.name
    assert_equal @anonymous_user.id, farm.user_id
    assert farm.latitude.present?
    assert farm.longitude.present?
  end

  test "should find or create default farm" do
    # 最初の呼び出しで作成
    farm1 = Farm.find_or_create_default_farm!
    assert farm1.persisted?
    assert farm1.is_default
    
    # 2回目の呼び出しでは既存のものを返す
    farm2 = Farm.find_or_create_default_farm!
    assert_equal farm1.id, farm2.id
  end

  test "should allow multiple default farms" do
    farm1 = Farm.create_default_farm!
    
    # 2つ目のデフォルト農場を作成（複数許可される）
    farm2 = Farm.create!(
      user: @anonymous_user,
      name: "別のデフォルト農場",
      latitude: 34.0,
      longitude: 135.0,
      is_default: true
    )
    
    assert farm2.valid?
    assert farm2.persisted?
    assert_equal 2, Farm.where(is_default: true).count
  end

  test "default farm must belong to anonymous user" do
    farm = Farm.new(
      user: @regular_user,
      name: "デフォルト農場",
      latitude: 35.0,
      longitude: 139.0,
      is_default: true
    )
    
    assert_not farm.valid?
    assert_includes farm.errors[:is_default], "デフォルト農場はアノニマスユーザーにのみ設定できます"
  end

  test "default_farm? should return true for default farm" do
    farm = Farm.create_default_farm!
    assert farm.default_farm?
  end

  test "default_farm? should return false for regular farm" do
    farm = farms(:one)
    assert_not farm.default_farm?
  end

  test "Farm.default_farm should return the default farm" do
    created_farm = Farm.create_default_farm!
    found_farm = Farm.default_farm
    
    assert_equal created_farm.id, found_farm.id
  end

  test "Farm.default_farm should return nil when no default farm exists" do
    # デフォルト農場が存在しない状態を確認
    Farm.where(is_default: true).destroy_all
    
    assert_nil Farm.default_farm
  end

  test "should allow updating default farm" do
    farm = Farm.create_default_farm!
    
    farm.name = "更新されたデフォルト農場"
    farm.latitude = 36.0
    farm.longitude = 140.0
    
    assert farm.save
    assert_equal "更新されたデフォルト農場", farm.reload.name
  end

  test "regular farm should not have is_default set to true" do
    farm = Farm.new(
      user: @regular_user,
      name: "通常の農場",
      latitude: 35.0,
      longitude: 139.0,
      is_default: false
    )
    
    assert farm.valid?
  end
end

