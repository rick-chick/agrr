# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Policies
      class PlanReadAuthorizationTest < DomainLibTestCase
        test "public_plan? matches plan_type public string" do
          assert PlanReadAuthorization.public_plan?(plan_type: "public")
          assert PlanReadAuthorization.public_plan?(plan_type: :public)
          assert_not PlanReadAuthorization.public_plan?(plan_type: "private")
        end
      end
    end
  end
end
