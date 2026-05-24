# frozen_string_literal: true

require "test_helper"

module Adapters
  module Crop
    module Mappers
      class CropAgrrRequirementMapperTest < ActiveSupport::TestCase
        test "build includes nutrients when present" do
          crop = create(:crop, :with_stages)
          crop.crop_stages.first.nutrient_requirement.update!(
            daily_uptake_n: 0.5,
            daily_uptake_p: 0.2,
            daily_uptake_k: 0.8
          )

          result = CropAgrrRequirementMapper.build(crop)

          stage_with_nutrients = result["stage_requirements"].find { |sr| sr["stage"]["name"] == crop.crop_stages.first.name }
          assert_not_nil stage_with_nutrients["nutrients"]
          assert_equal 0.5, stage_with_nutrients["nutrients"]["daily_uptake"]["N"]
          assert_equal 0.2, stage_with_nutrients["nutrients"]["daily_uptake"]["P"]
          assert_equal 0.8, stage_with_nutrients["nutrients"]["daily_uptake"]["K"]
        end

        test "build omits nutrients when absent" do
          crop = create(:crop)
          crop_stage = create(:crop_stage, crop: crop, order: 1)
          create(:temperature_requirement, crop_stage: crop_stage)
          create(:thermal_requirement, crop_stage: crop_stage)

          result = CropAgrrRequirementMapper.build(crop)

          assert_nil result["stage_requirements"].first["nutrients"]
        end

        test "build handles multiple stages with and without nutrients" do
          crop = create(:crop)

          stage1 = create(:crop_stage, crop: crop, name: "栄養成長期", order: 1)
          create(:temperature_requirement, crop_stage: stage1)
          create(:thermal_requirement, crop_stage: stage1)
          create(:nutrient_requirement, crop_stage: stage1, daily_uptake_n: 1.0, daily_uptake_p: 0.5, daily_uptake_k: 1.5)

          stage2 = create(:crop_stage, crop: crop, name: "成熟期", order: 2)
          create(:temperature_requirement, crop_stage: stage2)
          create(:thermal_requirement, crop_stage: stage2)

          result = CropAgrrRequirementMapper.build(crop)

          stage1_result = result["stage_requirements"].find { |sr| sr["stage"]["name"] == "栄養成長期" }
          assert_not_nil stage1_result["nutrients"]
          assert_equal 1.0, stage1_result["nutrients"]["daily_uptake"]["N"]

          stage2_result = result["stage_requirements"].find { |sr| sr["stage"]["name"] == "成熟期" }
          assert_nil stage2_result["nutrients"]
        end
      end
    end
  end
end
