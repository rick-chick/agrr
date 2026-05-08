# frozen_string_literal: true

require "test_helper"

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskDetailInteractorTest < ActiveSupport::TestCase
        test "calls on_success with detail dto when gateway succeeds" do
          user_id = 10
          task_id = 22
          user = Object.new
          detail_dto = Object.new

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = Minitest::Mock.new
          gateway.expect(:authorized_agricultural_task_detail_output, detail_dto, [ user, task_id ])

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
          gateway.verify
          output_port.verify
        end

        test "calls on_failure with policy exception when permission is denied" do
          user_id = 10
          task_id = 22
          user = Object.new

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = Object.new
          gateway.define_singleton_method(:authorized_agricultural_task_detail_output) do |_u, _tid|
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

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
