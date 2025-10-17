# frozen_string_literal: true

require "test_helper"

class CropRegionTest < ActiveSupport::TestCase
  def setup
    @user = users(:two)  # 一般ユーザー
    @admin = users(:one) # 管理者ユーザー
  end

  # 基本的なCRUD操作

  test "should create crop without region" do
    crop = Crop.create!(
      name: "Global Crop",
      user: @user,
      is_reference: false
    )
    
    assert_nil crop.region
    crop.reload
    assert_nil crop.region
  end

  test "should create crop with jp region" do
    crop = Crop.create!(
      name: "稲",
      user: @user,
      is_reference: false,
      region: "jp"
    )
    
    assert_equal "jp", crop.region
    crop.reload
    assert_equal "jp", crop.region
  end

  test "should create crop with us region" do
    crop = Crop.create!(
      name: "Corn",
      user: @user,
      is_reference: false,
      region: "us"
    )
    
    assert_equal "us", crop.region
    crop.reload
    assert_equal "us", crop.region
  end

  test "should update crop region" do
    crop = Crop.create!(
      name: "Rice",
      user: @user,
      is_reference: false
    )
    
    crop.update!(region: "jp")
    assert_equal "jp", crop.region
  end

  # by_regionスコープのテスト

  test "by_region scope should return only crops with specified region" do
    crop_jp1 = Crop.create!(name: "稲", user: @user, is_reference: false, region: "jp")
    crop_jp2 = Crop.create!(name: "大豆", user: @user, is_reference: false, region: "jp")
    crop_us = Crop.create!(name: "Corn", user: @user, is_reference: false, region: "us")
    crop_global = Crop.create!(name: "Wheat", user: @user, is_reference: false)
    
    jp_crops = Crop.by_region("jp")
    
    assert_equal 2, jp_crops.count
    assert_includes jp_crops, crop_jp1
    assert_includes jp_crops, crop_jp2
    assert_not_includes jp_crops, crop_us
    assert_not_includes jp_crops, crop_global
  end

  test "by_region scope should work with reference scope" do
    # 参照作物（システム提供）
    ref_jp = Crop.create!(name: "参照稲", is_reference: true, region: "jp")
    ref_us = Crop.create!(name: "Reference Corn", is_reference: true, region: "us")
    
    # ユーザー作物
    user_jp = Crop.create!(name: "ユーザー稲", user: @user, is_reference: false, region: "jp")
    
    # 日本の参照作物のみを取得
    jp_reference_crops = Crop.reference.by_region("jp")
    
    assert_equal 1, jp_reference_crops.count
    assert_includes jp_reference_crops, ref_jp
    assert_not_includes jp_reference_crops, ref_us
    assert_not_includes jp_reference_crops, user_jp
  end

  test "by_region scope should work with user_owned scope" do
    # ユーザー作物
    user_crop_jp = Crop.create!(name: "ユーザー稲", user: @user, is_reference: false, region: "jp")
    user_crop_us = Crop.create!(name: "User Corn", user: @user, is_reference: false, region: "us")
    
    # 参照作物
    Crop.create!(name: "参照稲", is_reference: true, region: "jp")
    
    # ユーザーの日本の作物のみを取得
    user_jp_crops = Crop.user_owned.by_region("jp")
    
    assert_equal 1, user_jp_crops.count
    assert_includes user_jp_crops, user_crop_jp
    assert_not_includes user_jp_crops, user_crop_us
  end

  # 実際の使用シナリオ

  test "should support providing region-specific reference crops" do
    # 日本用の参照作物（デフォルトで提供される作物）
    jp_crops = [
      Crop.create!(name: "コシヒカリ", variety: "水稲", is_reference: true, region: "jp", 
                   area_per_unit: 0.25, revenue_per_area: 5000),
      Crop.create!(name: "大豆", variety: "エンレイ", is_reference: true, region: "jp",
                   area_per_unit: 0.3, revenue_per_area: 3000),
      Crop.create!(name: "小麦", variety: "農林61号", is_reference: true, region: "jp",
                   area_per_unit: 0.2, revenue_per_area: 4000)
    ]
    
    # アメリカ用の参照作物
    us_crops = [
      Crop.create!(name: "Corn", variety: "Field Corn", is_reference: true, region: "us",
                   area_per_unit: 1.0, revenue_per_area: 8000),
      Crop.create!(name: "Soybean", variety: "Glycine max", is_reference: true, region: "us",
                   area_per_unit: 1.0, revenue_per_area: 6000),
      Crop.create!(name: "Wheat", variety: "Winter Wheat", is_reference: true, region: "us",
                   area_per_unit: 0.8, revenue_per_area: 7000)
    ]
    
    # 日本のユーザーには日本の参照作物を表示
    jp_reference_crops = Crop.reference.by_region("jp")
    assert_equal 3, jp_reference_crops.count
    jp_reference_crops.each do |crop|
      assert_equal "jp", crop.region
      assert crop.is_reference
    end
    
    # アメリカのユーザーにはアメリカの参照作物を表示
    us_reference_crops = Crop.reference.by_region("us")
    assert_equal 3, us_reference_crops.count
    us_reference_crops.each do |crop|
      assert_equal "us", crop.region
      assert crop.is_reference
    end
  end

  test "should allow user to create custom crop for specific region" do
    # ユーザーが日本向けのカスタム作物を作成
    custom_crop = Crop.create!(
      name: "特殊品種イチゴ",
      variety: "あまおう",
      user: @user,
      is_reference: false,
      region: "jp",
      area_per_unit: 0.1,
      revenue_per_area: 15000
    )
    
    assert_equal "jp", custom_crop.region
    assert_equal @user, custom_crop.user
    assert_not custom_crop.is_reference
  end

  test "should support global crops without region" do
    # 全地域共通の作物
    global_crop = Crop.create!(
      name: "Universal Crop",
      is_reference: true,
      region: nil
    )
    
    assert_nil global_crop.region
    assert global_crop.is_reference
    
    # 地域指定なしの検索では含まれない
    jp_crops = Crop.by_region("jp")
    assert_not_includes jp_crops, global_crop
  end

  test "should handle mixed region and global crops" do
    # グローバル作物
    Crop.create!(name: "Global 1", is_reference: true)
    Crop.create!(name: "Global 2", is_reference: true)
    
    # 日本の作物
    jp_crop = Crop.create!(name: "JP Crop", is_reference: true, region: "jp")
    
    # アメリカの作物
    Crop.create!(name: "US Crop", is_reference: true, region: "us")
    
    # 日本の作物のみを取得（グローバルは含まれない）
    jp_crops = Crop.reference.by_region("jp")
    assert_equal 1, jp_crops.count
    assert_includes jp_crops, jp_crop
  end

  test "should allow same crop name in different regions" do
    crop_jp = Crop.create!(
      name: "Rice",
      variety: "Japonica",
      is_reference: true,
      region: "jp"
    )
    
    crop_us = Crop.create!(
      name: "Rice",
      variety: "Long Grain",
      is_reference: true,
      region: "us"
    )
    
    assert crop_jp.valid?
    assert crop_us.valid?
    assert_not_equal crop_jp.id, crop_us.id
    assert_not_equal crop_jp.variety, crop_us.variety
  end
end

