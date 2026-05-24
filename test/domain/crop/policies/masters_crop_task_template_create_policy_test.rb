# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Policies
      class MastersCropTaskTemplateCreatePolicyTest < DomainLibTestCase
        test "duplicate? is true when link exists" do
          link = stub
          assert MastersCropTaskTemplateCreatePolicy.duplicate?(existing_link: link)
        end

        test "duplicate? is false when link is nil" do
          assert_not MastersCropTaskTemplateCreatePolicy.duplicate?(existing_link: nil)
        end

        test "build_persist_attributes uses task defaults when input fields are nil" do
          input = Dtos::MastersCropTaskTemplateCreateInput.new(
            user_id: 1,
            crop_id: 2,
            agricultural_task_id: 3
          )
          task = stub(
            name: "Task",
            description: "Desc",
            time_per_sqm: 1.5,
            weather_dependency: "low",
            required_tools: [ "hoe" ],
            skill_level: "beginner"
          )

          attrs = MastersCropTaskTemplateCreatePolicy.build_persist_attributes(input, task)

          assert_equal "Task", attrs.name
          assert_equal "Desc", attrs.description
          assert_equal 1.5, attrs.time_per_sqm
          assert_equal "low", attrs.weather_dependency
          assert_equal [ "hoe" ], attrs.required_tools
          assert_equal "beginner", attrs.skill_level
        end
      end
    end
  end
end
