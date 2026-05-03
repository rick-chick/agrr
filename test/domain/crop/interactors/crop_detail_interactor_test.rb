# frozen_string_literal: true

require "test_helper"

module Domain
  module Crop
    module Interactors
      class CropDetailInteractorTest < ActiveSupport::TestCase
        test "calls on_success with crop detail dto when gateway succeeds" do
          user_id = 10
          crop_id = 22
          user = Object.new
          crop_detail_dto = Object.new

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = Minitest::Mock.new
          gateway.expect(:find_authorized_crop_show_detail, crop_detail_dto, [ user, crop_id ])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = CropDetailInteractor.new(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
            logger: Object.new,
            user_lookup: user_lookup
          )

          interactor.call(crop_id)

          assert_equal crop_detail_dto, received
          user_lookup.verify
          gateway.verify
          output_port.verify
        end

        test "calls on_failure with policy exception when permission is denied" do
          user_id = 10
          crop_id = 22
          user = Object.new

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = Object.new
          gateway.define_singleton_method(:find_authorized_crop_show_detail) do |u, cid|
            raise Domain::Shared::Policies::PolicyPermissionDenied if u == user && cid == crop_id
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = CropDetailInteractor.new(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
            logger: Object.new,
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
