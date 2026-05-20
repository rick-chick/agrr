# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Policies
      class PlanReadAuthorizationTest < DomainLibTestCase
        test "private_plan_owned_by_actor? is true only when private and same owner" do
          assert PlanReadAuthorization.private_plan_owned_by_actor?(
            plan_type_private: true,
            plan_owner_user_id: 1,
            actor_user_id: 1
          )
          assert_not PlanReadAuthorization.private_plan_owned_by_actor?(
            plan_type_private: false,
            plan_owner_user_id: 1,
            actor_user_id: 1
          )
          assert_not PlanReadAuthorization.private_plan_owned_by_actor?(
            plan_type_private: true,
            plan_owner_user_id: 1,
            actor_user_id: 2
          )
        end

        test "public_plan? matches plan_type public string" do
          assert PlanReadAuthorization.public_plan?(plan_type: "public")
          assert PlanReadAuthorization.public_plan?(plan_type: :public)
          assert_not PlanReadAuthorization.public_plan?(plan_type: "private")
        end
      end
    end
  end
end
