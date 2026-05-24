# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropDetailInteractorTest < DomainLibTestCase
        test "calls on_success with crop detail dto when gateway succeeds" do
          user_id = 10
          crop_id = 22
          user = stub(id: user_id, admin?: false)
          crop = stub(is_reference: false, user_id: user_id, reference?: false)
          crop_detail_dto = stub(
            crop: crop,
            task_schedule_blueprints: [],
            available_agricultural_tasks: [],
            selected_task_ids: [],
            associated_pests: []
          )

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          gateway.expects(:find_crop_show_detail).with(crop_id).returns(crop_detail_dto)

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

          assert_instance_of Domain::Crop::Dtos::CropDetailOutput, received
          assert_equal crop, received.crop
          user_lookup.verify
          output_port.verify
        end

        test "calls on_failure with policy exception when permission is denied" do
          user_id = 10
          crop_id = 22
          user = stub(id: user_id, admin?: false)
          crop = stub(is_reference: false, user_id: 99, reference?: false)
          crop_detail_dto = stub(crop: crop)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          gateway.expects(:find_crop_show_detail).with(crop_id).returns(crop_detail_dto)

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
