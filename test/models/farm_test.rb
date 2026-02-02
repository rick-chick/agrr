# frozen_string_literal: true

require "test_helper"

class FarmTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
  end

  test "should validate region inclusion" do
    # Valid regions
    %w[jp us in].each do |region|
      farm = Farm.new(
        user: @user,
        name: "農場",
        latitude: 35.0,
        longitude: 135.0,
        region: region
      )
      assert farm.valid?, "Region '#{region}' should be valid"
    end

    # Invalid region
    farm = Farm.new(
      user: @user,
      name: "農場",
      latitude: 35.0,
      longitude: 135.0,
      region: "invalid"
    )
    assert_not farm.valid?
    assert_includes farm.errors[:region], "は一覧にありません"

    # Nil region should be valid
    farm = Farm.new(
      user: @user,
      name: "農場",
      latitude: 35.0,
      longitude: 135.0,
      region: nil
    )
    assert farm.valid?, "Nil region should be valid"
  end
end