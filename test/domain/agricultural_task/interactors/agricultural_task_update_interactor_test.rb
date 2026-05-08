# frozen_string_literal: true

require "test_helper"

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskUpdateInteractorTest < ActiveSupport::TestCase
        test "calls on_success when gateway updates" do
          user_id = 10
          user = Object.new
          task_entity = Object.new
          update_input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskUpdateInputDto.new(
            id: 5,
            name: "剪定"
          )

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = Minitest::Mock.new
          gateway.expect(:update_for_user, task_entity, [ user, 5, { name: "剪定" }, nil ])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = AgriculturalTaskUpdateInteractor.new(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
            translator: Object.new,
            user_lookup: user_lookup
          )

          result = interactor.call(update_input_dto)

          assert_equal true, result
          assert_equal task_entity, received
          user_lookup.verify
          gateway.verify
          output_port.verify
        end

        test "calls on_failure with policy_exception when permission is denied" do
          user_id = 10
          user = Object.new
          update_input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskUpdateInputDto.new(id: 5, name: "x")

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = Object.new
          gateway.define_singleton_method(:update_for_user) do |_u, _id, _attrs, _selected = nil|
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = AgriculturalTaskUpdateInteractor.new(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
            translator: Object.new,
            user_lookup: user_lookup
          )

          result = interactor.call(update_input_dto)

          assert_equal false, result
          assert_instance_of Domain::Shared::Policies::PolicyPermissionDenied, received
          user_lookup.verify
          output_port.verify
        end
      end
    end
  end
end
