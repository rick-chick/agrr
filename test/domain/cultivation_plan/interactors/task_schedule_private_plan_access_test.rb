# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class TaskSchedulePrivatePlanAccessTest < DomainLibTestCase
        test "access_allowed? is true for private plan owned by user" do
          plan_gateway = mock
          plan_gateway.expects(:find_by_id).with(2).returns(
            Entities::CultivationPlanEntity.new(
              id: 2,
              farm_id: 1,
              user_id: 1,
              total_area: 0,
              plan_type: "private"
            )
          )

          assert TaskSchedulePrivatePlanAccess.access_allowed?(
            plan_gateway: plan_gateway,
            plan_id: 2,
            user_id: 1
          )
        end

        test "access_allowed? is false for another users private plan" do
          plan_gateway = mock
          plan_gateway.expects(:find_by_id).with(2).returns(
            Entities::CultivationPlanEntity.new(
              id: 2,
              farm_id: 1,
              user_id: 99,
              total_area: 0,
              plan_type: "private"
            )
          )

          refute TaskSchedulePrivatePlanAccess.access_allowed?(
            plan_gateway: plan_gateway,
            plan_id: 2,
            user_id: 1
          )
        end
      end
    end
  end
end
