# frozen_string_literal: true

require "test_helper"

class FarmRegionTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @anonymous_user = User.create!(
      name: "Anonymous User",
      email: "anonymous@example.com",
      google_id: "anonymous_#{SecureRandom.hex(8)}",
      is_anonymous: true
    )
  end

  # 基本的なCRUD操作

  test "should create farm without region" do
    farm = Farm.create!(
      name: "Global Farm",
      user: @user,
      latitude: 35.6762,
      longitude: 139.6503
    )
    
    assert_nil farm.region
    farm.reload
    assert_nil farm.region
  end

  test "should create farm with jp region" do
    farm = Farm.create!(
      name: "Tokyo Farm",
      user: @user,
      latitude: 35.6762,
      longitude: 139.6503,
      region: "jp"
    )
    
    assert_equal "jp", farm.region
    farm.reload
    assert_equal "jp", farm.region
  end

  test "should create farm with us region" do
    farm = Farm.create!(
      name: "Iowa Farm",
      user: @user,
      latitude: 42.0308,
      longitude: -93.6319,
      region: "us"
    )
    
    assert_equal "us", farm.region
    farm.reload
    assert_equal "us", farm.region
  end

  test "should update farm region from nil to jp" do
    farm = Farm.create!(
      name: "Farm to Update",
      user: @user,
      latitude: 35.0,
      longitude: 135.0
    )
    
    assert_nil farm.region
    
    farm.update!(region: "jp")
    assert_equal "jp", farm.region
    
    farm.reload
    assert_equal "jp", farm.region
  end

  test "should update farm region from jp to us" do
    farm = Farm.create!(
      name: "Farm to Change",
      user: @user,
      latitude: 35.0,
      longitude: 135.0,
      region: "jp"
    )
    
    farm.update!(region: "us")
    assert_equal "us", farm.region
  end

  test "should clear farm region" do
    farm = Farm.create!(
      name: "Farm to Clear",
      user: @user,
      latitude: 35.0,
      longitude: 135.0,
      region: "jp"
    )
    
    farm.update!(region: nil)
    assert_nil farm.region
  end

  # by_regionスコープのテスト

  test "by_region scope should return only farms with specified region" do
    farm_jp1 = Farm.create!(name: "Tokyo Farm", user: @user, latitude: 35.68, longitude: 139.65, region: "jp")
    farm_jp2 = Farm.create!(name: "Osaka Farm", user: @user, latitude: 34.69, longitude: 135.50, region: "jp")
    farm_us = Farm.create!(name: "Iowa Farm", user: @user, latitude: 42.03, longitude: -93.63, region: "us")
    farm_global = Farm.create!(name: "Global Farm", user: @user, latitude: 40.00, longitude: 140.00)
    
    jp_farms = Farm.by_region("jp")
    
    assert_equal 2, jp_farms.count
    assert_includes jp_farms, farm_jp1
    assert_includes jp_farms, farm_jp2
    assert_not_includes jp_farms, farm_us
    assert_not_includes jp_farms, farm_global
  end

  test "by_region scope should not include nil region farms" do
    Farm.create!(name: "JP Farm", user: @user, latitude: 35.0, longitude: 135.0, region: "jp")
    Farm.create!(name: "Global Farm 1", user: @user, latitude: 35.0, longitude: 135.0)
    Farm.create!(name: "Global Farm 2", user: @user, latitude: 36.0, longitude: 136.0)
    
    jp_farms = Farm.by_region("jp")
    
    assert_equal 1, jp_farms.count
  end

  test "by_region scope should return empty when no matching region" do
    Farm.create!(name: "JP Farm", user: @user, latitude: 35.0, longitude: 135.0, region: "jp")
    Farm.create!(name: "US Farm", user: @user, latitude: 42.0, longitude: -93.0, region: "us")
    
    eu_farms = Farm.by_region("eu")
    
    assert_equal 0, eu_farms.count
    assert_empty eu_farms
  end

  test "by_region scope should work with other scopes" do
    user2 = User.create!(
      email: "user2_region@example.com",
      name: "User 2",
      google_id: "google_#{SecureRandom.hex(8)}"
    )
    
    farm1 = Farm.create!(name: "User1 JP Farm", user: @user, latitude: 35.0, longitude: 135.0, region: "jp")
    farm2 = Farm.create!(name: "User2 JP Farm", user: user2, latitude: 36.0, longitude: 136.0, region: "jp")
    Farm.create!(name: "User1 US Farm", user: @user, latitude: 42.0, longitude: -93.0, region: "us")
    
    user1_jp_farms = Farm.by_user(@user).by_region("jp")
    
    assert_equal 1, user1_jp_farms.count
    assert_includes user1_jp_farms, farm1
    assert_not_includes user1_jp_farms, farm2
  end

  test "by_region scope should work with reference scope" do
    # 日本の参照農場
    jp_ref_farm = Farm.create!(
      name: "東京サンプル農場",
      user: @anonymous_user,
      latitude: 35.6762,
      longitude: 139.6503,
      is_reference: true,
      region: "jp"
    )
    
    # アメリカの参照農場
    us_ref_farm = Farm.create!(
      name: "Iowa Reference Farm",
      user: @anonymous_user,
      latitude: 42.0308,
      longitude: -93.6319,
      is_reference: true,
      region: "us"
    )
    
    # ユーザー農場
    user_farm = Farm.create!(
      name: "User Farm",
      user: @user,
      latitude: 35.0,
      longitude: 135.0,
      region: "jp"
    )
    
    # 日本の参照農場のみを取得
    jp_reference_farms = Farm.reference.by_region("jp")
    
    assert_equal 1, jp_reference_farms.count
    assert_includes jp_reference_farms, jp_ref_farm
    assert_not_includes jp_reference_farms, us_ref_farm
    assert_not_includes jp_reference_farms, user_farm
  end

  # 実際の使用シナリオ

  test "should support providing region-specific reference farms" do
    # 日本の主要地域の参照農場
    jp_farms = [
      Farm.create!(
        name: "北海道サンプル農場",
        user: @anonymous_user,
        latitude: 43.06,
        longitude: 141.35,
        is_reference: true,
        region: "jp"
      ),
      Farm.create!(
        name: "東京サンプル農場",
        user: @anonymous_user,
        latitude: 35.68,
        longitude: 139.65,
        is_reference: true,
        region: "jp"
      ),
      Farm.create!(
        name: "九州サンプル農場",
        user: @anonymous_user,
        latitude: 33.59,
        longitude: 130.42,
        is_reference: true,
        region: "jp"
      )
    ]
    
    # アメリカの主要地域の参照農場
    us_farms = [
      Farm.create!(
        name: "Iowa Corn Belt Farm",
        user: @anonymous_user,
        latitude: 42.03,
        longitude: -93.63,
        is_reference: true,
        region: "us"
      ),
      Farm.create!(
        name: "California Central Valley Farm",
        user: @anonymous_user,
        latitude: 36.74,
        longitude: -119.78,
        is_reference: true,
        region: "us"
      ),
      Farm.create!(
        name: "Texas Panhandle Farm",
        user: @anonymous_user,
        latitude: 35.22,
        longitude: -101.83,
        is_reference: true,
        region: "us"
      )
    ]
    
    # 日本のユーザーには日本の参照農場を表示
    jp_reference_farms = Farm.reference.by_region("jp")
    assert_equal 3, jp_reference_farms.count
    jp_reference_farms.each do |farm|
      assert_equal "jp", farm.region
      assert farm.is_reference
      assert farm.user.anonymous?
    end
    
    # アメリカのユーザーにはアメリカの参照農場を表示
    us_reference_farms = Farm.reference.by_region("us")
    assert_equal 3, us_reference_farms.count
    us_reference_farms.each do |farm|
      assert_equal "us", farm.region
      assert farm.is_reference
      assert farm.user.anonymous?
    end
  end

  test "should order reference farms by latitude descending within region" do
    # 日本の農場を緯度順に作成（実際は順不同で作成）
    kyushu = Farm.create!(
      name: "九州農場",
      user: @anonymous_user,
      latitude: 33.0,
      longitude: 130.0,
      is_reference: true,
      region: "jp"
    )
    
    hokkaido = Farm.create!(
      name: "北海道農場",
      user: @anonymous_user,
      latitude: 43.0,
      longitude: 141.0,
      is_reference: true,
      region: "jp"
    )
    
    tokyo = Farm.create!(
      name: "東京農場",
      user: @anonymous_user,
      latitude: 35.0,
      longitude: 139.0,
      is_reference: true,
      region: "jp"
    )
    
    # 参照農場は北から南の順（緯度降順）
    jp_farms = Farm.reference.by_region("jp")
    assert_equal [hokkaido, tokyo, kyushu], jp_farms.to_a
  end

  test "should allow user to create custom farm for specific region" do
    # ユーザーが日本向けの農場を作成
    custom_farm = Farm.create!(
      name: "私の農場",
      user: @user,
      latitude: 35.0,
      longitude: 135.0,
      region: "jp"
    )
    
    assert_equal "jp", custom_farm.region
    assert_equal @user, custom_farm.user
    assert_not custom_farm.is_reference
  end

  test "should support global farms without region" do
    # 全地域共通の農場
    global_farm = Farm.create!(
      name: "Global Research Farm",
      user: @user,
      latitude: 35.0,
      longitude: 135.0,
      region: nil
    )
    
    assert_nil global_farm.region
    
    # 地域指定なしの検索では含まれない
    jp_farms = Farm.by_region("jp")
    assert_not_includes jp_farms, global_farm
  end

  test "should allow same farm name in different regions" do
    farm_jp = Farm.create!(
      name: "Sample Farm",
      user: @user,
      latitude: 35.0,
      longitude: 135.0,
      region: "jp"
    )
    
    farm_us = Farm.create!(
      name: "Sample Farm",
      user: @user,
      latitude: 42.0,
      longitude: -93.0,
      region: "us"
    )
    
    assert farm_jp.valid?
    assert farm_us.valid?
    assert_not_equal farm_jp.id, farm_us.id
    assert_not_equal farm_jp.coordinates, farm_us.coordinates
  end

  test "should support region-specific weather patterns" do
    # 日本の農場（温帯・モンスーン気候）
    jp_farm = Farm.create!(
      name: "日本の農場",
      user: @user,
      latitude: 35.6762,
      longitude: 139.6503,
      region: "jp"
    )
    
    # アメリカの農場（大陸性気候）
    us_farm = Farm.create!(
      name: "Iowa Farm",
      user: @user,
      latitude: 42.0308,
      longitude: -93.6319,
      region: "us"
    )
    
    # 各地域の農場は異なる気候データを持つ
    assert_equal "jp", jp_farm.region
    assert_equal "us", us_farm.region
    
    # 地域別に適切な気候データと栽培推奨が提供される
    jp_farms = Farm.by_region("jp")
    us_farms = Farm.by_region("us")
    
    assert_includes jp_farms, jp_farm
    assert_includes us_farms, us_farm
  end

  test "reference farm should belong to anonymous user" do
    farm = Farm.create!(
      name: "Reference Farm",
      user: @anonymous_user,
      latitude: 35.0,
      longitude: 135.0,
      is_reference: true,
      region: "jp"
    )
    
    assert farm.valid?
    assert farm.is_reference
    assert farm.user.anonymous?
  end

  test "reference farm with region should not belong to regular user" do
    farm = Farm.new(
      name: "Invalid Reference Farm",
      user: @user,
      latitude: 35.0,
      longitude: 135.0,
      is_reference: true,
      region: "jp"
    )
    
    assert_not farm.valid?
    assert_includes farm.errors[:is_reference], "参照農場はアノニマスユーザーにのみ設定できます"
  end

  test "should combine region filter with user filter and reference filter" do
    # 日本の参照農場
    jp_ref = Farm.create!(
      name: "JP Reference",
      user: @anonymous_user,
      latitude: 35.0,
      longitude: 135.0,
      is_reference: true,
      region: "jp"
    )
    
    # アメリカの参照農場
    us_ref = Farm.create!(
      name: "US Reference",
      user: @anonymous_user,
      latitude: 42.0,
      longitude: -93.0,
      is_reference: true,
      region: "us"
    )
    
    # ユーザーの日本の農場
    user_jp = Farm.create!(
      name: "User JP Farm",
      user: @user,
      latitude: 36.0,
      longitude: 136.0,
      is_reference: false,
      region: "jp"
    )
    
    # 日本の参照農場のみ
    jp_refs = Farm.reference.by_region("jp")
    assert_equal 1, jp_refs.count
    assert_includes jp_refs, jp_ref
    
    # アメリカの参照農場のみ
    us_refs = Farm.reference.by_region("us")
    assert_equal 1, us_refs.count
    assert_includes us_refs, us_ref
    
    # ユーザーの日本の農場のみ
    user_jp_farms = Farm.user_owned.by_user(@user).by_region("jp")
    assert_equal 1, user_jp_farms.count
    assert_includes user_jp_farms, user_jp
  end
end

