# frozen_string_literal: true

require "test_helper"

module Adapters
  module CultivationPlan
    class PlanSaveAgriculturalTaskIdLookupTest < ActiveSupport::TestCase
      test "returns cached map entry without gateway call" do
        map = { 5 => 99 }
        gateway = mock("gateway")
        gateway.expects(:find_by_user_id_and_source_agricultural_task_id).never

        assert_equal 99, PlanSaveAgriculturalTaskIdLookup.resolve(
          reference_task_id: 5,
          user_id: 1,
          map: map,
          plan_save_user_agricultural_task_gateway: gateway
        )
      end

      test "fallback find writes resolved id into map for subsequent lookups" do
        map = {}
        gateway = mock("gateway")
        gateway.expects(:find_by_user_id_and_source_agricultural_task_id).with(
          user_id: 1,
          source_agricultural_task_id: 5
        ).once.returns(
          Domain::CultivationPlan::Dtos::PlanSaveUserAgriculturalTaskSnapshot.new(id: 88, name: "作業")
        )

        first = PlanSaveAgriculturalTaskIdLookup.resolve(
          reference_task_id: 5,
          user_id: 1,
          map: map,
          plan_save_user_agricultural_task_gateway: gateway
        )
        second = PlanSaveAgriculturalTaskIdLookup.resolve(
          reference_task_id: 5,
          user_id: 1,
          map: map,
          plan_save_user_agricultural_task_gateway: gateway
        )

        assert_equal 88, first
        assert_equal 88, second
        assert_equal({ 5 => 88 }, map)
      end
    end
  end
end
