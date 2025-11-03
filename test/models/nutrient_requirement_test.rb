# frozen_string_literal: true

require "test_helper"

class NutrientRequirementTest < ActiveSupport::TestCase
  setup do
    @crop_stage = create(:crop_stage)
  end

  test "should create nutrient requirement with valid data" do
    nutrient_req = NutrientRequirement.new(
      crop_stage: @crop_stage,
      daily_uptake_n: 0.5,
      daily_uptake_p: 0.2,
      daily_uptake_k: 0.8
    )
    
    assert nutrient_req.valid?
    assert nutrient_req.save
  end

  test "should require crop_stage" do
    nutrient_req = NutrientRequirement.new(
      daily_uptake_n: 0.5,
      daily_uptake_p: 0.2,
      daily_uptake_k: 0.8
    )
    
    assert_not nutrient_req.valid?
    assert_includes nutrient_req.errors[:crop_stage], "を入力してください"
  end

  test "should validate daily_uptake_n is non-negative" do
    nutrient_req = NutrientRequirement.new(
      crop_stage: @crop_stage,
      daily_uptake_n: -1.0,
      daily_uptake_p: 0.2,
      daily_uptake_k: 0.8
    )
    
    assert_not nutrient_req.valid?
    assert_includes nutrient_req.errors[:daily_uptake_n], "は0以上の値にしてください"
  end

  test "should validate daily_uptake_p is non-negative" do
    nutrient_req = NutrientRequirement.new(
      crop_stage: @crop_stage,
      daily_uptake_n: 0.5,
      daily_uptake_p: -0.1,
      daily_uptake_k: 0.8
    )
    
    assert_not nutrient_req.valid?
    assert_includes nutrient_req.errors[:daily_uptake_p], "は0以上の値にしてください"
  end

  test "should validate daily_uptake_k is non-negative" do
    nutrient_req = NutrientRequirement.new(
      crop_stage: @crop_stage,
      daily_uptake_n: 0.5,
      daily_uptake_p: 0.2,
      daily_uptake_k: -0.5
    )
    
    assert_not nutrient_req.valid?
    assert_includes nutrient_req.errors[:daily_uptake_k], "は0以上の値にしてください"
  end

  test "should allow nil values for uptake values" do
    nutrient_req = NutrientRequirement.new(
      crop_stage: @crop_stage,
      daily_uptake_n: nil,
      daily_uptake_p: nil,
      daily_uptake_k: nil
    )
    
    assert nutrient_req.valid?
  end

  test "should belong to crop_stage" do
    nutrient_req = create(:nutrient_requirement, crop_stage: @crop_stage)
    
    assert_equal @crop_stage, nutrient_req.crop_stage
  end

  test "should have factory with traits" do
    assert create(:nutrient_requirement, :vegetative_high)
    assert create(:nutrient_requirement, :flowering_high)
    assert create(:nutrient_requirement, :fruiting_high)
    assert create(:nutrient_requirement, :low_intake)
  end

  test "crop stage should have nutrient requirement" do
    create(:nutrient_requirement, crop_stage: @crop_stage)
    
    assert_not_nil @crop_stage.nutrient_requirement
    assert_equal 0.5, @crop_stage.nutrient_requirement.daily_uptake_n
    assert_equal 0.2, @crop_stage.nutrient_requirement.daily_uptake_p
    assert_equal 0.8, @crop_stage.nutrient_requirement.daily_uptake_k
  end
end
