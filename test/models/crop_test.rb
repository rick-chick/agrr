# frozen_string_literal: true

require "test_helper"

class CropTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
  end

  test "should validate region inclusion" do
    # Valid regions
    %w[jp us in].each do |region|
      crop = Crop.new(user: @user, name: "作物", region: region)
      assert crop.valid?, "Region '#{region}' should be valid"
    end

    # Invalid region
    crop = Crop.new(user: @user, name: "作物", region: "invalid")
    assert_not crop.valid?
    assert_includes crop.errors[:region], "は一覧にありません"

    # Nil region should be valid
    crop = Crop.new(user: @user, name: "作物", region: nil)
    assert crop.valid?, "Nil region should be valid"
  end

  test "should validate user presence for non-reference crops" do
    crop = Crop.new(user: nil, name: "作物", is_reference: false)
    # Should have validation error for missing user
    crop.valid? # triggers validations
    assert_equal 1, crop.errors[:user].count
    assert_includes crop.errors[:user], "を入力してください"
  end

  test "should not allow user for reference crops" do
    crop = Crop.new(user: @user, name: "参照作物", is_reference: true)
    crop.valid?

    assert_includes crop.errors[:user], "は参照データには設定できません"
  end
end
