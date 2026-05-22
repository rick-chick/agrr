# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskUpdateInteractorTest < DomainLibTestCase
        test "calls on_success when gateway updates" do
          user_id = 10
          user = Object.new
          def user.admin? = false
          task_entity = Object.new
          update_input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskUpdateInput.new(
            id: 5,
            name: "剪定"
          )

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          current = Object.new
          current.define_singleton_method(:reference?) { false }

          gateway = Object.new
          gateway.define_singleton_method(:find_authorized_for_edit) { |_u, _id, **_kw| current }
          gateway.define_singleton_method(:update_for_user) { |_u, _id, _attrs, **_kw| task_entity }

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
          output_port.verify
        end

        test "calls on_failure with policy_exception when permission is denied" do
          user_id = 10
          user = Object.new
          def user.admin? = false
          update_input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskUpdateInput.new(id: 5, name: "x")

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          current = Object.new
          current.define_singleton_method(:reference?) { false }

          gateway = Object.new
          gateway.define_singleton_method(:find_authorized_for_edit) { |_u, _id, **_kw| current }
          gateway.define_singleton_method(:update_for_user) do |_u, _id, _attrs, **_kw|
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

        test "一般ユーザーが is_reference を変更しようとすると on_failure（reference_flag_admin_only）" do
          user_id = 10
          user = Object.new
          def user.admin? = false
          dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskUpdateInput.new(id: 5, is_reference: true)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          current = Object.new
          current.define_singleton_method(:reference?) { false }

          gateway = Object.new
          gateway.define_singleton_method(:find_authorized_for_edit) { |_u, _id, **_kw| current }
          gateway.define_singleton_method(:update_for_user) { |*| flunk "update_for_user should not be called" }

          translator = Object.new
          def translator.t(key) = key

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          result = AgriculturalTaskUpdateInteractor.new(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
            translator: translator,
            user_lookup: user_lookup
          ).call(dto)

          assert_equal false, result
          assert_equal "agricultural_tasks.flash.reference_flag_admin_only", received.message
          user_lookup.verify
          output_port.verify
        end
      end
    end
  end
end
