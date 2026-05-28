# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropListReferenceEntitiesInteractorTest < DomainLibTestCase
        setup do
          @gateway = mock("crop_gateway")
          @output_port = mock("output_port")
          @logger = mock("logger")
          @interactor = CropListReferenceEntitiesInteractor.new(
            output_port: @output_port,
            gateway: @gateway,
            logger: @logger
          )
        end

        test "on_success lists reference crops filtered by region" do
          crops = [ Object.new ]
          @gateway.expects(:list_by_is_reference).with(is_reference: true, region: "jp").returns(crops)
          @output_port.expects(:on_success).with(crops)

          @interactor.call(region: "jp")
        end

        test "on_success without region passes nil region to gateway" do
          @gateway.expects(:list_by_is_reference).with(is_reference: true, region: nil).returns([])
          @output_port.expects(:on_success).with([])

          @interactor.call(region: nil)
        end

        test "on_failure when gateway raises RecordInvalid" do
          @gateway.expects(:list_by_is_reference).raises(
            Domain::Shared::Exceptions::RecordInvalid.new("bad query")
          )
          @logger.expects(:error).never
          @output_port.expects(:on_failure).with do |dto|
            dto.is_a?(Domain::Shared::Dtos::Error) && dto.message == "bad query"
          end

          @interactor.call(region: "jp")
        end
      end
    end
  end
end
