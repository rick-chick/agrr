# frozen_string_literal: true

require "test_helper"

module Adapters
  module Crop
    module Mappers
      class CropTaskTemplateAgrrFormatMapperTest < ActiveSupport::TestCase
        test "build converts template to agrr CLI format" do
          template = create(:crop_task_template,
            name: "土壌準備",
            description: "耕す",
            time_per_sqm: 0.1,
            weather_dependency: "low",
            required_tools: [ "トラクター" ],
            skill_level: "beginner")

          format = CropTaskTemplateAgrrFormatMapper.build(template)

          assert_equal template.id.to_s, format["task_id"]
          assert_equal "土壌準備", format["name"]
          assert_equal 0.1, format["time_per_sqm"]
          assert_equal [ "トラクター" ], format["required_tools"]
        end

        test "build_array converts multiple templates" do
          crop = create(:crop)
          template1 = create(:crop_task_template, crop: crop, name: "タスク1")
          template2 = create(:crop_task_template, crop: crop, name: "タスク2", agricultural_task: nil)

          array = CropTaskTemplateAgrrFormatMapper.build_array([ template1, template2 ])

          assert_equal 2, array.length
          assert_equal template1.id.to_s, array[0]["task_id"]
          assert_equal template2.id.to_s, array[1]["task_id"]
        end
      end
    end
  end
end
