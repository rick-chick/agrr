# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class PlanCopyInteractorTest < DomainLibTestCase
        def source_plan_stub
          OpenStruct.new(
            id: 1,
            farm_id: 7,
            total_area: 20.0,
            plan_name: "Source"
          )
        end

        def field_stub(id:)
          OpenStruct.new(id: id, name: "F#{id}", area: 1.0, daily_fixed_cost: 0, description: nil)
        end

        def crop_stub(id:)
          OpenStruct.new(
            id: id,
            crop_id: 100 + id,
            name: "C#{id}",
            variety: "v",
            area_per_unit: 0.2,
            revenue_per_area: 100.0
          )
        end

        def fc_stub(id:, field_id:, crop_id:)
          OpenStruct.new(
            id: id,
            cultivation_plan_field_id: field_id,
            cultivation_plan_crop_id: crop_id,
            area: 1.0,
            status: "pending"
          )
        end

        def build_interactor(gateway:, logger: nil)
          PlanCopyInteractor.new(
            plan_copy_gateway: gateway,
            logger: logger || CapturingLogger.new
          )
        end

        test "creates plan with session_id and copies relations via gateway" do
          gateway = mock("plan_copy_gateway")
          gateway.expects(:find_plan).with(source_plan_id: 1).returns(source_plan_stub)
          gateway.expects(:find_plan).with(source_plan_id: 99).returns(OpenStruct.new(id: 99, farm_id: 7))
          gateway.expects(:create_plan).with do |attrs:|
            assert_equal 7, attrs.farm_id
            assert_equal 42, attrs.user_id
            assert_equal "private", attrs.plan_type
            assert_equal 2027, attrs.plan_year
            assert_equal "ws-1", attrs.session_id
            true
          end.returns(OpenStruct.new(id: 99))
          gateway.expects(:list_fields).with(source_plan_id: 1).returns([ field_stub(id: 10) ])
          gateway.expects(:create_field).returns(field_stub(id: 20))
          gateway.expects(:list_crops).with(source_plan_id: 1).returns([ crop_stub(id: 11) ])
          gateway.expects(:create_crop).returns(crop_stub(id: 21))
          gateway.expects(:list_field_cultivations).with(source_plan_id: 1).returns(
            [ fc_stub(id: 30, field_id: 10, crop_id: 11) ]
          )
          gateway.expects(:create_field_cultivation).with(
            plan_id: 99,
            cultivation_plan_field_id: 20,
            cultivation_plan_crop_id: 21,
            area: 1.0,
            status: "pending"
          )

          out = build_interactor(gateway: gateway).call(
            Dtos::PlanCopyInput.new(
              source_cultivation_plan_id: 1,
              new_year: 2027,
              user_id: 42,
              session_id: "ws-1"
            )
          )

          assert_equal 99, out.id
        end

        test "logs plan copy completion" do
          gateway = mock("plan_copy_gateway")
          gateway.stubs(:find_plan).returns(source_plan_stub)
          gateway.stubs(:create_plan).returns(OpenStruct.new(id: 99))
          gateway.stubs(:list_fields).returns([])
          gateway.stubs(:list_crops).returns([])
          gateway.stubs(:list_field_cultivations).returns([])
          gateway.stubs(:find_plan).with(source_plan_id: 99).returns(OpenStruct.new(id: 99))

          log = CapturingLogger.new
          build_interactor(gateway: gateway, logger: log).call(
            Dtos::PlanCopyInput.new(
              source_cultivation_plan_id: 1,
              new_year: 2027,
              user_id: 42
            )
          )

          assert(
            log.entries.any? { |lvl, msg| lvl == :info && msg.include?("Plan copy completed") },
            "expected completion log"
          )
        end
      end
    end
  end
end
