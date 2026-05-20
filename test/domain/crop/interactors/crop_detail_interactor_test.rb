# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropDetailInteractorTest < DomainLibTestCase
        test "calls on_success with crop detail dto when gateway succeeds" do
          user_id = 10
          crop_id = 22
          user = Object.new
          crop_detail_dto = Object.new

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          gateway.expects(:find_authorized_crop_show_detail).with(
            user,
            crop_id,
            access_filter: instance_of(Domain::Shared::ReferenceRecordAccessFilter)
          ).returns(crop_detail_dto)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = CropDetailInteractor.new(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
            user_lookup: user_lookup
          )

          interactor.call(crop_id)

          assert_equal crop_detail_dto, received
          user_lookup.verify
          output_port.verify
        end

        test "calls on_failure with policy exception when permission is denied" do
          user_id = 10
          crop_id = 22
          user = Object.new

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          gateway.expects(:find_authorized_crop_show_detail).with(
            user,
            crop_id,
            access_filter: instance_of(Domain::Shared::ReferenceRecordAccessFilter)
          ).raises(Domain::Shared::Policies::PolicyPermissionDenied)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = CropDetailInteractor.new(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
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
