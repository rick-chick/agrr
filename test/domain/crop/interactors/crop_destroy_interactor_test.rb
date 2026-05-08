# frozen_string_literal: true

require "test_helper"

module Domain
  module Crop
    module Interactors
      class CropDestroyInteractorTest < ActiveSupport::TestCase
        test "calls on_success when gateway returns success" do
          user_id = 10
          crop_id = 22
          user = Object.new
          undo_entity = Object.new

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = Object.new
          gateway.define_singleton_method(:soft_destroy_with_undo) do |**_kwargs|
            { success: true, undo_entity: undo_entity }
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = CropDestroyInteractor.new(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
            translator: Object.new,
            user_lookup: user_lookup
          )

          interactor.call(crop_id)

          assert_instance_of Domain::Crop::Dtos::CropDestroyOutputDto, received
          assert_equal undo_entity, received.undo
          user_lookup.verify
          output_port.verify
        end

        test "calls on_failure with policy exception when permission is denied" do
          user_id = 10
          crop_id = 22
          user = Object.new

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = Object.new
          gateway.define_singleton_method(:soft_destroy_with_undo) do |**_kwargs|
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = CropDestroyInteractor.new(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
            translator: Object.new,
            user_lookup: user_lookup
          )

          interactor.call(crop_id)

          assert_instance_of Domain::Shared::Policies::PolicyPermissionDenied, received
          user_lookup.verify
          output_port.verify
        end
      end
    end
  end
end
