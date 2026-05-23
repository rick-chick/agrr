# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropDestroyInteractorTest < DomainLibTestCase
        test "calls on_success when gateway returns success" do
          user_id = 10
          crop_id = 22
          user = domain_user_stub(id: user_id, admin: false)
          undo_entity = Object.new
          crop_entity = domain_record_entity_stub(user_id: user_id, is_reference: false)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          usage = Domain::Crop::Dtos::CropDeleteUsage.new(
            cultivation_plan_crops_count: 0,
            free_crop_plans_count: 0,
            pesticides_count: 0
          )

          gateway = mock
          gateway.expects(:find_by_id).with(crop_id).returns(crop_entity)
          gateway.expects(:find_delete_usage).with(crop_id).returns(usage)
          gateway.expects(:soft_delete_with_undo).returns({ success: true, undo_entity: undo_entity })

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

          assert_instance_of Domain::Crop::Dtos::CropDestroyOutput, received
          assert_equal undo_entity, received.undo
          user_lookup.verify
          output_port.verify
        end

        test "calls on_failure with policy exception when permission is denied" do
          user_id = 10
          crop_id = 22
          user = domain_user_stub(id: user_id, admin: false)
          crop_entity = domain_record_entity_stub(user_id: 99, is_reference: false)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          gateway.expects(:find_by_id).with(crop_id).returns(crop_entity)
          gateway.expects(:find_delete_usage).never
          gateway.expects(:soft_delete_with_undo).never

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

        test "calls on_failure when cultivation plan crops block delete" do
          user_id = 10
          crop_id = 22
          user = domain_user_stub(id: user_id, admin: false)
          crop_entity = domain_record_entity_stub(user_id: user_id, is_reference: false)
          usage = Domain::Crop::Dtos::CropDeleteUsage.new(
            cultivation_plan_crops_count: 1,
            free_crop_plans_count: 0,
            pesticides_count: 0
          )
          translator = mock
          translator.expects(:t).with("crops.flash.cannot_delete_in_use.plan").returns("blocked")

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          gateway.expects(:find_by_id).with(crop_id).returns(crop_entity)
          gateway.expects(:find_delete_usage).with(crop_id).returns(usage)
          gateway.expects(:soft_delete_with_undo).never

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = CropDestroyInteractor.new(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
            translator: translator,
            user_lookup: user_lookup
          )

          interactor.call(crop_id)

          assert_instance_of Domain::Shared::Dtos::Error, received
          assert_equal "blocked", received.message
          user_lookup.verify
          output_port.verify
        end
      end
    end
  end
end
