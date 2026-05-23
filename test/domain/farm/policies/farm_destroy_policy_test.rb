# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Farm
    module Policies
      class FarmDestroyPolicyTest < DomainLibTestCase
        test "blocked_reason is nil when no free crop plans" do
          usage = Domain::Farm::Dtos::FarmDeleteUsage.new(free_crop_plans_count: 0)

          assert_nil FarmDestroyPolicy.blocked_reason(usage)
        end

        test "blocked_reason is free_crop_plans when count positive" do
          usage = Domain::Farm::Dtos::FarmDeleteUsage.new(free_crop_plans_count: 2)

          assert_equal :free_crop_plans, FarmDestroyPolicy.blocked_reason(usage)
        end
      end
    end
  end
end
