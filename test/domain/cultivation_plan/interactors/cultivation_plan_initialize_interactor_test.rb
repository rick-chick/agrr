# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class CultivationPlanInitializeInteractorTest < DomainLibTestCase
        setup do
          @farm = stub(id: 1, name: "Farm")
          @crop = stub(id: 10, name: "Crop", variety: "V", area_per_unit: 1.0, revenue_per_area: 100.0)
          @clock = Object.new
          def @clock.today
            Date.new(2026, 3, 1)
          end
          @logger = ::Logger.new(File::NULL)
          @cultivation_plan_gateway = mock("cultivation_plan_gateway")
          @plan_crop_gateway = mock("plan_crop_gateway")
          @field_mutation_gateway = mock("field_mutation_gateway")
        end

        test "returns failure result when total_area is not positive" do
          interactor = CultivationPlanInitializeInteractor.new(
            farm: @farm,
            total_area: 0,
            crops: [ @crop ],
            cultivation_plan_gateway: @cultivation_plan_gateway,
            plan_crop_gateway: @plan_crop_gateway,
            field_mutation_gateway: @field_mutation_gateway,
            clock: @clock,
            logger: @logger
          )

          result = interactor.call

          assert_not result.success?
          assert_includes result.errors.first, "総面積"
        end

        test "creates plan crops and fields inside transaction when valid" do
          plan_entity = stub(id: 99)
          reloaded = stub(id: 99)

          @cultivation_plan_gateway.expects(:within_transaction).yields
          @cultivation_plan_gateway.expects(:create).returns(plan_entity)
          @plan_crop_gateway.expects(:create_for_plan).once
          @field_mutation_gateway.expects(:create_field).at_least_once
          @cultivation_plan_gateway.expects(:find_by_id).with(99).returns(reloaded)

          interactor = CultivationPlanInitializeInteractor.new(
            farm: @farm,
            total_area: 100.0,
            crops: [ @crop ],
            cultivation_plan_gateway: @cultivation_plan_gateway,
            plan_crop_gateway: @plan_crop_gateway,
            field_mutation_gateway: @field_mutation_gateway,
            clock: @clock,
            logger: @logger,
            plan_type: "public"
          )

          result = interactor.call

          assert result.success?
          assert_equal reloaded, result.cultivation_plan
        end
      end
    end
  end
end
