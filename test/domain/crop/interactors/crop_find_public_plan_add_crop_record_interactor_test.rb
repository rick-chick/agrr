# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropFindPublicPlanAddCropRecordInteractorTest < DomainLibTestCase
        setup do
          @crop = Entities::CropEntity.new(
            id: 1,
            user_id: nil,
            name: "参照トマト",
            variety: nil,
            is_reference: true,
            area_per_unit: 1.0,
            revenue_per_area: 2.0,
            region: "jp",
            groups: [],
            crop_stages: [],
            created_at: Time.utc(2026, 1, 1),
            updated_at: Time.utc(2026, 1, 1)
          )
        end

        test "calls on_success when gateway returns reference crop" do
          gateway = Minitest::Mock.new
          gateway.expect(:find_reference_crop_record_for_public_plan_add_crop, @crop, [ "42" ])

          output = Minitest::Mock.new
          output.expect(:on_success, nil, [ @crop ])

          logger = Minitest::Mock.new

          interactor = CropFindPublicPlanAddCropRecordInteractor.new(
            output_port: output,
            gateway: gateway,
            logger: logger
          )

          assert_nil interactor.call("42")

          gateway.verify
          output.verify
        end

        test "calls on_failure when gateway returns nil" do
          gateway = Minitest::Mock.new
          gateway.expect(:find_reference_crop_record_for_public_plan_add_crop, nil, [ "99" ])

          output = Minitest::Mock.new
          output.expect(:on_failure, nil, [ Domain::Shared::Dtos::Error ])

          logger = Minitest::Mock.new
          logger.expect(:warn, nil, [ String ])

          interactor = CropFindPublicPlanAddCropRecordInteractor.new(
            output_port: output,
            gateway: gateway,
            logger: logger
          )

          assert_nil interactor.call("99")

          gateway.verify
          output.verify
          logger.verify
        end
      end
    end
  end
end
