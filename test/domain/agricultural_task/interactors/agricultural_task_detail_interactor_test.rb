# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskDetailInteractorTest < DomainLibTestCase
        test "calls on_success with detail dto when gateway succeeds" do
          user_id = 10
          task_id = 22
          user = stub(id: user_id, admin?: false)
          task_entity = stub(is_reference: false, user_id: user_id)
          detail_dto = Object.new

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          gateway.expects(:find_by_id).with(task_id).returns(task_entity)
          gateway.expects(:authorized_agricultural_task_detail_output).with(task_id).returns(detail_dto)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = AgriculturalTaskDetailInteractor.new(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
            user_lookup: user_lookup
          )

          interactor.call(task_id)

          assert_equal detail_dto, received
          user_lookup.verify
          output_port.verify
        end

        test "calls on_failure with policy exception when permission is denied" do
          user_id = 10
          task_id = 22
          user = stub(id: user_id, admin?: false)
          task_entity = stub(is_reference: false, user_id: 99)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          gateway.expects(:find_by_id).with(task_id).returns(task_entity)
          gateway.expects(:authorized_agricultural_task_detail_output).never

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = AgriculturalTaskDetailInteractor.new(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
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
