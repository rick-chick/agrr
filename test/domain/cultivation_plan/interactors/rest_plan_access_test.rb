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

        test "workbench_read_access_denied? applies PlanReadAuthorization to plan header" do
          private_auth = Dtos::CultivationPlanRestAuth.new(mode: :private, user_id: 1)
          public_auth = Dtos::CultivationPlanRestAuth.new(mode: :public)

          owned_header = Dtos::CultivationPlanWorkbenchPlanHeader.new(
            id: 1, user_id: 1, plan_year: 2026, plan_name: "p", plan_type: "private",
            status: "draft", total_area: 0.0,
            planning_start_date: nil, planning_end_date: nil,
            total_profit: 0.0, total_revenue: 0.0, total_cost: 0.0
          )
          other_header = Dtos::CultivationPlanWorkbenchPlanHeader.new(
            id: 2, user_id: 2, plan_year: 2026, plan_name: "p", plan_type: "private",
            status: "draft", total_area: 0.0,
            planning_start_date: nil, planning_end_date: nil,
            total_profit: 0.0, total_revenue: 0.0, total_cost: 0.0
          )
          public_header = Dtos::CultivationPlanWorkbenchPlanHeader.new(
            id: 3, user_id: nil, plan_year: 2026, plan_name: "p", plan_type: "public",
            status: "draft", total_area: 0.0,
            planning_start_date: nil, planning_end_date: nil,
            total_profit: 0.0, total_revenue: 0.0, total_cost: 0.0
          )

          refute RestPlanAccess.workbench_read_access_denied?(plan_header: owned_header, auth: private_auth)
          assert RestPlanAccess.workbench_read_access_denied?(plan_header: other_header, auth: private_auth)
          refute RestPlanAccess.workbench_read_access_denied?(plan_header: public_header, auth: public_auth)
          assert RestPlanAccess.workbench_read_access_denied?(
            plan_header: owned_header,
            auth: public_auth
          )
        end
      end
    end
  end
end
