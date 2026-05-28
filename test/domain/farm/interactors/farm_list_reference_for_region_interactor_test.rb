# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Farm
    module Interactors
      class FarmListReferenceForRegionInteractorTest < DomainLibTestCase
        setup do
          @gateway = mock("farm_gateway")
          @output_port = mock("output_port")
          @logger = mock("logger")
          @interactor = FarmListReferenceForRegionInteractor.new(
            output_port: @output_port,
            gateway: @gateway,
            logger: @logger
          )
        end

        test "on_success with reference farms for region" do
          farms = [ Object.new, Object.new ]
          @gateway.expects(:list_reference_farms_for_region).with("jp").returns(farms)
          @output_port.expects(:on_success).with(farms)

          @interactor.call("jp")
        end

        test "on_failure when gateway raises RecordInvalid" do
          @gateway.expects(:list_reference_farms_for_region).with("us").raises(
            Domain::Shared::Exceptions::RecordInvalid.new("invalid region")
          )
          @logger.expects(:error).with("[FarmListReferenceForRegionInteractor] invalid region")
          @output_port.expects(:on_failure).with do |dto|
            dto.is_a?(Domain::Shared::Dtos::Error) && dto.message == "invalid region"
          end

          @interactor.call("us")
        end
      end
    end
  end
end
