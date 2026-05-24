# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskDestroyInteractorTest < DomainLibTestCase
        test "calls on_success when gateway returns success" do
          user_id = 10
          task_id = 22
          user = domain_user_stub(id: user_id, admin: false)
          undo_entity = Object.new
          task_entity = domain_record_entity_stub(user_id: user_id, is_reference: false, name: "除草")

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          translator = mock
          translator.expects(:t).with("agricultural_tasks.undo.toast", name: "除草").returns("toast")

          gateway = mock
          gateway.expects(:find_by_id).with(task_id).returns(task_entity)
          gateway.expects(:soft_delete_with_undo).with(
            user: user,
            task_id: task_id,
            auto_hide_after: 5000,
            toast_message: "toast"
          ).returns({ success: true, undo_entity: undo_entity })

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = AgriculturalTaskDestroyInteractor.new(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
            translator: translator,
            user_lookup: user_lookup
          )

          interactor.call(task_id)

          assert_instance_of Domain::AgriculturalTask::Dtos::AgriculturalTaskDestroyOutput, received
          assert_equal undo_entity, received.undo
          user_lookup.verify
          output_port.verify
        end

        test "calls on_failure with policy exception when permission is denied" do
          user_id = 10
          task_id = 22
          user = domain_user_stub(id: user_id, admin: false)
          task_entity = domain_record_entity_stub(user_id: 99, is_reference: false)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          gateway.expects(:find_by_id).with(task_id).returns(task_entity)
          gateway.expects(:soft_delete_with_undo).never

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = AgriculturalTaskDestroyInteractor.new(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
            translator: Object.new,
            user_lookup: user_lookup
          )

          interactor.call(task_id)

          assert_instance_of Domain::Shared::Policies::PolicyPermissionDenied, received
          user_lookup.verify
          output_port.verify
        end
      end
    end
  end
end
