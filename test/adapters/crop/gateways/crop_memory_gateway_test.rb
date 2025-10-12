# frozen_string_literal: true

require 'test_helper'

class Adapters::Crop::Gateways::CropMemoryGatewayTest < ActiveSupport::TestCase
  def setup
    @gateway = Adapters::Crop::Gateways::CropMemoryGateway.new
    @user = users(:one)
    @crop_data = {
      user_id: @user.id,
      name: "稲",
      variety: "コシヒカリ",
      is_reference: false
    }
  end

  test "should create crop" do
    crop = @gateway.create(@crop_data)
    assert_not_nil crop
    assert_equal "稲", crop.name
    assert_equal "コシヒカリ", crop.variety
    assert_equal false, crop.reference?
    assert crop.is_a?(Domain::Crop::Entities::CropEntity)
  end

  test "should create crop with area and revenue fields" do
    crop_data = @crop_data.merge(
      area_per_unit: 100.0,
      revenue_per_area: 500000.0
    )
    crop = @gateway.create(crop_data)
    assert_not_nil crop
    assert_equal 100.0, crop.area_per_unit
    assert_equal 500000.0, crop.revenue_per_area
  end

  test "should create crop with nil revenue_per_area" do
    crop_data = @crop_data.merge(
      area_per_unit: 100.0,
      revenue_per_area: nil
    )
    crop = @gateway.create(crop_data)
    assert_not_nil crop
    assert_equal 100.0, crop.area_per_unit
    assert_nil crop.revenue_per_area
  end

  test "should find crop by id" do
    created = @gateway.create(@crop_data)
    found = @gateway.find_by_id(created.id)
    assert_not_nil found
    assert_equal created.id, found.id
  end

  test "should list visible crops for user (includes reference)" do
    @gateway.create(@crop_data)
    @gateway.create(@crop_data.merge(name: "稲(基準)", is_reference: true, user_id: nil))
    list = @gateway.find_all_visible_for(@user.id)
    names = list.map(&:name)
    assert_includes names, "稲"
    assert_includes names, "稲(基準)"
  end

  test "should update crop" do
    created = @gateway.create(@crop_data)
    updated = @gateway.update(created.id, { name: "稲(更新)" })
    assert_equal "稲(更新)", updated.name
  end

  test "should update area and revenue fields" do
    created = @gateway.create(@crop_data.merge(area_per_unit: 100.0, revenue_per_area: 500000.0))
    updated = @gateway.update(created.id, { area_per_unit: 150.0, revenue_per_area: 600000.0 })
    assert_equal 150.0, updated.area_per_unit
    assert_equal 600000.0, updated.revenue_per_area
  end

  test "should delete crop" do
    created = @gateway.create(@crop_data)
    assert @gateway.delete(created.id)
    assert_nil @gateway.find_by_id(created.id)
  end

  test "should check exists" do
    created = @gateway.create(@crop_data)
    assert @gateway.exists?(created.id)
    assert_not @gateway.exists?(999999)
  end
end


