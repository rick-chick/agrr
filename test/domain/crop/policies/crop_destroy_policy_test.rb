# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Policies
      class CropDestroyPolicyTest < DomainLibTestCase
        test "blocked_reason is cultivation_plan when plan crops exist" do
          usage = Domain::Crop::Dtos::CropDeleteUsage.new(
            cultivation_plan_crops_count: 1,
            free_crop_plans_count: 0,
            pesticides_count: 0
          )

          assert_equal :cultivation_plan, CropDestroyPolicy.blocked_reason(usage)
        end

        test "blocked_reason is other when free crop plans exist" do
          usage = Domain::Crop::Dtos::CropDeleteUsage.new(
            cultivation_plan_crops_count: 0,
            free_crop_plans_count: 1,
            pesticides_count: 0
          )

          assert_equal :other, CropDestroyPolicy.blocked_reason(usage)
        end

        test "blocked_reason is nil when no associations" do
          usage = Domain::Crop::Dtos::CropDeleteUsage.new(
            cultivation_plan_crops_count: 0,
            free_crop_plans_count: 0,
            pesticides_count: 0
          )

          assert_nil CropDestroyPolicy.blocked_reason(usage)
        end
      end
    end
  end
end
