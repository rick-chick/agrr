# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropStageListInteractorTest < DomainLibTestCase
        test "calls on_success with crop stages when gateway succeeds" do
          crop_stages = [
            Domain::Crop::Entities::CropStageEntity.new(
              id: 1,
              crop_id: 1,
              name: "種まき",
              order: 1,
              created_at: Time.utc(2026, 1, 1),
              updated_at: Time.utc(2026, 1, 1)
            )
          ]
          gateway = Minitest::Mock.new
          gateway.expect(:list_by_crop_id, crop_stages, [ 1 ])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = CropStageListInteractor.new(output_port: output_port, gateway: gateway)
          input_dto = Domain::Crop::Dtos::CropStageListInput.new(crop_id: 1)
          interactor.call(input_dto)

          assert_equal crop_stages, received.stages
          gateway.verify
          output_port.verify
        end

        test "calls on_failure with Error when gateway raises RecordInvalid" do
          gateway = Minitest::Mock.new
          gateway.expect(:list_by_crop_id, nil) do |_crop_id|
            raise Domain::Shared::Exceptions::RecordInvalid.new("crop inaccessible")
          end

          received_failure = nil
          output_port = Object.new
          output_port.define_singleton_method(:on_success) { |_| raise "must not call on_success" }
          output_port.define_singleton_method(:on_failure) { |dto| received_failure = dto }

          interactor = CropStageListInteractor.new(output_port: output_port, gateway: gateway)
          input_dto = Domain::Crop::Dtos::CropStageListInput.new(crop_id: 1)
          interactor.call(input_dto)

          assert_instance_of Domain::Shared::Dtos::Error, received_failure
          assert_equal "crop inaccessible", received_failure.message
          gateway.verify
        end

        test "propagates StandardError when gateway raises" do
          gateway = Minitest::Mock.new
          gateway.expect(:list_by_crop_id, nil) { raise StandardError, "database error" }

          output_port = Minitest::Mock.new

          interactor = CropStageListInteractor.new(output_port: output_port, gateway: gateway)
          input_dto = Domain::Crop::Dtos::CropStageListInput.new(crop_id: 1)
          err = assert_raises(StandardError) do
            interactor.call(input_dto)
          end
          assert_includes err.message, "database error"
          gateway.verify
        end
      end
    end
  end
end
