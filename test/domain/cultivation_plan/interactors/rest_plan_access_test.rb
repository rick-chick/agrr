# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class RestPlanAccessTest < DomainLibTestCase
        test "access_denied? delegates private plans to PrivateCultivationPlanAccessPolicy" do
          auth = Dtos::CultivationPlanRestAuth.new(mode: :private, user_id: 1)
          owned = Entities::CultivationPlanEntity.new(
            id: 1, farm_id: 1, user_id: 1, total_area: 0, plan_type: "private"
          )
          other = Entities::CultivationPlanEntity.new(
            id: 2, farm_id: 1, user_id: 2, total_area: 0, plan_type: "private"
          )

          refute RestPlanAccess.access_denied?(plan: owned, auth: auth)
          assert RestPlanAccess.access_denied?(plan: other, auth: auth)
        end

        test "access_denied? requires public plan_type for public REST auth" do
          auth = Dtos::CultivationPlanRestAuth.new(mode: :public)
          public_plan = Entities::CultivationPlanEntity.new(
            id: 1, farm_id: 1, user_id: 1, total_area: 0, plan_type: "public"
          )
          private_plan = Entities::CultivationPlanEntity.new(
            id: 2, farm_id: 1, user_id: 1, total_area: 0, plan_type: "private"
          )

          refute RestPlanAccess.access_denied?(plan: public_plan, auth: auth)
          assert RestPlanAccess.access_denied?(plan: private_plan, auth: auth)
        end
      end
    end
  end
end
