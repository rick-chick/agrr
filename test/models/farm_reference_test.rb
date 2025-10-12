# frozen_string_literal: true

require "test_helper"

class FarmReferenceTest < ActiveSupport::TestCase
  def setup
    # アノニマスユーザーを確実に作成
    User.instance_variable_set(:@anonymous_user, nil)
    @anonymous_user = User.anonymous_user
    @regular_user = users(:one)
    
    # 既存の参照農場を削除（テスト用）
    Farm.where(is_reference: true).destroy_all
  end

  test "should allow multiple reference farms" do
    farm1 = Farm.create!(
      user: @anonymous_user,
      name: "参照農場1",
      latitude: 35.0,
      longitude: 139.0,
      is_reference: true
    )
    
    # 2つ目の参照農場を作成（複数許可される）
    farm2 = Farm.create!(
      user: @anonymous_user,
      name: "参照農場2",
      latitude: 34.0,
      longitude: 135.0,
      is_reference: true
    )
    
    assert farm2.valid?
    assert farm2.persisted?
    assert_equal 2, Farm.where(is_reference: true).count
  end

  test "reference farm must belong to anonymous user" do
    farm = Farm.new(
      user: @regular_user,
      name: "参照農場",
      latitude: 35.0,
      longitude: 139.0,
      is_reference: true
    )
    
    assert_not farm.valid?
    assert_includes farm.errors[:is_reference], "参照農場はアノニマスユーザーにのみ設定できます"
  end

  test "reference? should return true for reference farm" do
    farm = Farm.create!(
      user: @anonymous_user,
      name: "参照農場",
      latitude: 35.0,
      longitude: 139.0,
      is_reference: true
    )
    assert farm.reference?
  end

  test "reference? should return false for regular farm" do
    farm = farms(:one)
    assert_not farm.reference?
  end

  test "Farm.reference scope should return reference farms" do
    farm1 = Farm.create!(
      user: @anonymous_user,
      name: "参照農場1",
      latitude: 35.0,
      longitude: 139.0,
      is_reference: true
    )
    
    farm2 = Farm.create!(
      user: @anonymous_user,
      name: "参照農場2",
      latitude: 34.0,
      longitude: 135.0,
      is_reference: true
    )
    
    reference_farms = Farm.reference
    assert_equal 2, reference_farms.count
    assert_includes reference_farms, farm1
    assert_includes reference_farms, farm2
  end

  test "should allow updating reference farm" do
    farm = Farm.create!(
      user: @anonymous_user,
      name: "参照農場",
      latitude: 35.0,
      longitude: 139.0,
      is_reference: true
    )
    
    farm.name = "更新された参照農場"
    farm.latitude = 36.0
    farm.longitude = 140.0
    
    assert farm.save
    assert_equal "更新された参照農場", farm.reload.name
  end

  test "regular farm should not have is_reference set to true" do
    farm = Farm.new(
      user: @regular_user,
      name: "通常の農場",
      latitude: 35.0,
      longitude: 139.0,
      is_reference: false
    )
    
    assert farm.valid?
  end
end

