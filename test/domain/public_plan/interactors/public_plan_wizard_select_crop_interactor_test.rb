# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module PublicPlan
    module Interactors
      class PublicPlanWizardSelectCropInteractorTest < DomainLibTestCase
        class RecordingPort < Domain::PublicPlan::Ports::PublicPlanWizardSelectCropOutputPort
          attr_reader :last_dto, :last_event

          def on_missing_session
            @last_event = :missing_session
          end

          def on_missing_farm
            @last_event = :missing_farm
          end

          def on_invalid_farm_size(farm_id:)
            @last_event = :invalid_farm_size
            @last_farm_id = farm_id
          end

          def on_success(dto)
            @last_event = :success
            @last_dto = dto
          end
        end

        setup do
          now = Time.utc(2026, 1, 1)
          @farm = Domain::Farm::Entities::FarmEntity.new(
            id: 1,
            name: "Test",
            region: "jp",
            latitude: 35.0,
            longitude: 139.0,
            user_id: nil,
            is_reference: true,
            created_at: now,
            updated_at: now
          )
          @port = RecordingPort.new
          @public_plan_gateway = Minitest::Mock.new
          @crop_gateway = Minitest::Mock.new
          @logger = Logger.new(nil)
        end

        test "on_missing_session when farm_id blank" do
          interactor = PublicPlanWizardSelectCropInteractor.new(
            public_plan_gateway: @public_plan_gateway,
            crop_gateway: @crop_gateway,
            output_port: @port,
            logger: @logger
          )
          interactor.call(farm_id: nil, farm_size_id: "home_garden")
          assert_equal :missing_session, @port.last_event
        end

        test "on_success merges session patch with farm_size and crops" do
          farm_size = { id: "home_garden", area_sqm: 30 }
          crops = [ Object.new ]

          @public_plan_gateway.expect(:find_by_farm_id, @farm, [ 1 ])
          @public_plan_gateway.expect(:find_by_farm_size_id, farm_size, [ "home_garden" ])
          @crop_gateway.expect(:list_reference_crop_entities, crops, [], region: "jp")

          interactor = PublicPlanWizardSelectCropInteractor.new(
            public_plan_gateway: @public_plan_gateway,
            crop_gateway: @crop_gateway,
            output_port: @port,
            logger: @logger
          )
          interactor.call(farm_id: 1, farm_size_id: "home_garden")

          assert_equal :success, @port.last_event
          assert_equal({ total_area: 30, farm_size_id: "home_garden" }, @port.last_dto.session_patch)
          assert_equal crops, @port.last_dto.crops
          @public_plan_gateway.verify
          @crop_gateway.verify
        end
      end
    end
  end
end
