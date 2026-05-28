# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropFindReferenceForEntryScheduleInteractorTest < DomainLibTestCase
        setup do
          @gateway = mock
          @output_port = mock
          @logger = mock
          @logger.stubs(:warn)
        end

        def interactor
          CropFindReferenceForEntryScheduleInteractor.new(
            output_port: @output_port,
            gateway: @gateway,
            logger: @logger
          )
        end

        test "on_success for reference crop in region" do
          crop = stub(id: 1, is_reference: true, region: "jp")
          input = Dtos::CropFindReferenceForEntryScheduleInput.new(region: "jp", crop_id: 1)
          @gateway.expects(:find_crop_record_with_stages!).with(1).returns(crop)
          @output_port.expects(:on_success).with(crop)

          interactor.call(input)
        end

        test "on_failure when crop is not reference" do
          crop = stub(id: 2, is_reference: false, region: "jp")
          input = Dtos::CropFindReferenceForEntryScheduleInput.new(region: "jp", crop_id: 2)
          @gateway.expects(:find_crop_record_with_stages!).with(2).returns(crop)
          @output_port.expects(:on_failure).with(instance_of(Domain::Shared::Dtos::Error))

          interactor.call(input)
        end

        test "on_failure when region mismatches" do
          crop = stub(id: 3, is_reference: true, region: "us")
          input = Dtos::CropFindReferenceForEntryScheduleInput.new(region: "jp", crop_id: 3)
          @gateway.expects(:find_crop_record_with_stages!).with(3).returns(crop)
          @output_port.expects(:on_failure).with(instance_of(Domain::Shared::Dtos::Error))

          interactor.call(input)
        end
      end
    end
  end
end
