# frozen_string_literal: true

require "test_helper"

class FarmLimitIntegrationTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "farm_limit_integration_test@example.com",
      name: "Farm Limit Integration Test User",
      google_id: "farm_limit_integration_test_123",
      is_anonymous: false
    )
  end

  def teardown
    @user.destroy if @user.persisted?
  end

  test "should allow creating up to 4 farms per user" do
    # 農場を4つまで作成
    (1..4).each do |i|
      farm = Farm.create!(
        user: @user,
        name: "テスト農場 #{i}",
        latitude: 35.0 + i * 0.1,
        longitude: 135.0 + i * 0.1,
        is_reference: false
      )
      assert farm.persisted?, "Farm #{i} should be created successfully"
    end

    assert_equal 4, @user.farms.where(is_reference: false).count
  end

  test "should prevent creating 5th farm" do
    4.times do |i|
      Farm.create!(
        user: @user,
        name: "既存農場 #{i + 1}",
        latitude: 35.0 + i * 0.1,
        longitude: 135.0 + i * 0.1,
        is_reference: false
      )
    end

    count = @user.farms.where(is_reference: false).count
    assert_equal 4, count
    assert Domain::Farm::Policies::FarmCreateLimitPolicy.limit_exceeded?(
      existing_non_reference_count: count
    )
  end

  test "should allow unlimited reference farms" do
    anonymous_user = User.anonymous_user
    initial_count = anonymous_user.farms.where(is_reference: true).count

    # 参照農場を複数作成
    5.times do |i|
      ref_farm = Farm.create!(
        user: anonymous_user,
        name: "参照農場テスト #{i + 1}",
        latitude: 36.0 + i * 0.1,
        longitude: 136.0 + i * 0.1,
        is_reference: true
      )
      assert ref_farm.persisted?, "Reference farm #{i + 1} should be created successfully"
    end

    expected_count = initial_count + 5
    assert_equal expected_count, anonymous_user.farms.where(is_reference: true).count
  end

  test "should work correctly with existing farms" do
    # 既存の農場がある状態で新しい農場を作成
    existing_farm = Farm.create!(
      user: @user,
      name: "既存農場",
      latitude: 35.0,
      longitude: 135.0,
      is_reference: false
    )

    # 残り3つの農場を作成
    3.times do |i|
      farm = Farm.create!(
        user: @user,
        name: "追加農場 #{i + 1}",
        latitude: 35.1 + i * 0.1,
        longitude: 135.1 + i * 0.1,
        is_reference: false
      )
      assert farm.persisted?, "Additional farm #{i + 1} should be created successfully"
    end

    assert_equal 4, @user.farms.where(is_reference: false).count

    count = @user.farms.where(is_reference: false).count
    assert Domain::Farm::Policies::FarmCreateLimitPolicy.limit_exceeded?(
      existing_non_reference_count: count
    )
  end
end
