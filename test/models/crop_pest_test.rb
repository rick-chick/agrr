# frozen_string_literal: true

require "test_helper"

class CropPestTest < ActiveSupport::TestCase
  setup do
    @crop = create(:crop)
    @pest = create(:pest)
  end

  test "should belong to crop" do
    crop_pest = create(:crop_pest, crop: @crop, pest: @pest)
    assert_equal @crop, crop_pest.crop
  end

  test "should belong to pest" do
    crop_pest = create(:crop_pest, crop: @crop, pest: @pest)
    assert_equal @pest, crop_pest.pest
  end

  test "should validate crop presence" do
    crop_pest = CropPest.new(pest: @pest)
    assert_not crop_pest.valid?
    assert_includes crop_pest.errors[:crop], "を入力してください"
  end

  test "should validate pest presence" do
    crop_pest = CropPest.new(crop: @crop)
    assert_not crop_pest.valid?
    assert_includes crop_pest.errors[:pest], "を入力してください"
  end

  test "should validate uniqueness of pest_id scoped to crop_id" do
    create(:crop_pest, crop: @crop, pest: @pest)
    
    duplicate = CropPest.new(crop: @crop, pest: @pest)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:pest_id], "はすでに存在します"
  end

  test "should allow same pest for different crops" do
    crop1 = create(:crop)
    crop2 = create(:crop)
    
    crop_pest1 = create(:crop_pest, crop: crop1, pest: @pest)
    crop_pest2 = create(:crop_pest, crop: crop2, pest: @pest)
    
    assert crop_pest1.valid?
    assert crop_pest2.valid?
    assert_equal @pest, crop_pest1.pest
    assert_equal @pest, crop_pest2.pest
  end

  test "should allow different pests for same crop" do
    pest1 = create(:pest)
    pest2 = create(:pest)
    
    crop_pest1 = create(:crop_pest, crop: @crop, pest: pest1)
    crop_pest2 = create(:crop_pest, crop: @crop, pest: pest2)
    
    assert crop_pest1.valid?
    assert crop_pest2.valid?
    assert_equal @crop, crop_pest1.crop
    assert_equal @crop, crop_pest2.crop
  end
end

