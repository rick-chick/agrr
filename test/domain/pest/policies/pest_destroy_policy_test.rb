# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pest
    module Policies
      class PestDestroyPolicyTest < DomainLibTestCase
        test "blocked_reason is nil when no pesticides" do
          usage = Domain::Pest::Dtos::PestDeleteUsage.new(pesticides_count: 0)

          assert_nil PestDestroyPolicy.blocked_reason(usage)
        end

        test "blocked_reason is pesticides_in_use when count positive" do
          usage = Domain::Pest::Dtos::PestDeleteUsage.new(pesticides_count: 1)

          assert_equal :pesticides_in_use, PestDestroyPolicy.blocked_reason(usage)
        end
      end
    end
  end
end
