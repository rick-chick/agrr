# frozen_string_literal: true

require "test_helper"

module Adapters
  module CultivationPlan
    module Gateways
      class PublicPlanSaveReadActiveRecordGatewayTest < ActiveSupport::TestCase
        setup do
          @gateway = PublicPlanSaveReadActiveRecordGateway.new
          @farm = ::Farm.reference.first || ::Farm.create!(
            user: User.anonymous_user,
            name: "Ref",
            latitude: 35.0,
            longitude: 139.0,
            is_reference: true,
            region: "jp"
          )
          @plan = ::CultivationPlan.create!(
            farm: @farm,
            user: nil,
            total_area: 10.0,
            plan_type: "public",
            plan_year: Date.current.year,
            plan_name: "ReadGwTest",
            planning_start_date: Date.current,
            planning_end_date: Date.current.end_of_year,
            status: "completed"
          )
          ::CultivationPlanField.create!(
            cultivation_plan: @plan,
            name: "F1",
            area: 5.0,
            daily_fixed_cost: 0
          )
        end

        test "find_header returns snapshot for existing plan" do
          header = @gateway.find_header(plan_id: @plan.id)
          assert_equal @plan.id, header.plan_id
          assert_equal @farm.id, header.farm_id
        end

        test "find_header returns nil for missing plan" do
          assert_nil @gateway.find_header(plan_id: -1)
        end

        test "list_field_rows returns field datums" do
          rows = @gateway.list_field_rows(plan_id: @plan.id)
          assert_equal 1, rows.size
          assert_equal "F1", rows.first.name
        end
      end
    end
  end
end
