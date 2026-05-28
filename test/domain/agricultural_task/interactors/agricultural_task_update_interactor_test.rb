# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskUpdateInteractorTest < DomainLibTestCase
        def build_interactor(output_port:, user_id:, gateway:, user_lookup:, translator: Object.new,
                             crop_gateway: nil, crop_task_template_gateway: nil)
          if nil.equal?(crop_gateway) && nil.equal?(crop_task_template_gateway)
            crop_gateway, crop_task_template_gateway = null_crop_gateways
          end
          AgriculturalTaskUpdateInteractor.new(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
            crop_gateway: crop_gateway,
            crop_task_template_gateway: crop_task_template_gateway,
            translator: translator,
            user_lookup: user_lookup
          )
        end

        def null_crop_gateways
          crop_gateway = Object.new
          crop_gateway.define_singleton_method(:list_by_is_reference) { |**| [] }
          crop_gateway.define_singleton_method(:list_by_user_id) { |**| [] }
          crop_gateway.define_singleton_method(:find_by_id) { |*| raise Domain::Shared::Exceptions::RecordNotFound, "not found" }
          template_gateway = Object.new
          template_gateway.define_singleton_method(:list_by_agricultural_task_id) { |**| [] }
          template_gateway.define_singleton_method(:find_by_agricultural_task_id_and_crop_id) { |**| nil }
          template_gateway.define_singleton_method(:create) { |**| nil }
          template_gateway.define_singleton_method(:delete) { |**| nil }
          [crop_gateway, template_gateway]
        end

        test "calls on_success when gateway updates" do
          user_id = 10
          user = domain_user_stub(id: user_id, admin: false)
          task_entity = Object.new
          update_input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskUpdateInput.new(
            id: 5,
            name: "剪定"
          )

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          current = domain_record_entity_stub(user_id: user_id, is_reference: false)
          current.stubs(:reference?).returns(false)

          gateway = Object.new
          gateway.define_singleton_method(:find_by_id) { |_id| current }
          gateway.define_singleton_method(:find_by_user_id_and_name) { |**| nil }
          gateway.define_singleton_method(:within_transaction) { |&block| block.call }
          gateway.define_singleton_method(:update) { |_id, _attrs| task_entity }

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = build_interactor(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
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
          user = domain_user_stub(id: user_id, admin: false)
          update_input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskUpdateInput.new(id: 5, name: "x")

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          current = domain_record_entity_stub(user_id: 99, is_reference: false)
          current.stubs(:reference?).returns(false)

          gateway = Object.new
          gateway.define_singleton_method(:find_by_id) { |_id| current }
          gateway.define_singleton_method(:update) { |*| flunk "update should not be called" }

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = build_interactor(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
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
          user = domain_user_stub(id: user_id, admin: false)
          dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskUpdateInput.new(id: 5, is_reference: true)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          current = domain_record_entity_stub(user_id: user_id, is_reference: false)
          current.stubs(:reference?).returns(false)

          gateway = Object.new
          gateway.define_singleton_method(:find_by_id) { |_id| current }
          gateway.define_singleton_method(:update) { |*| flunk "update should not be called" }

          translator = Object.new
          def translator.t(key) = key

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          result = build_interactor(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
            translator: translator,
            user_lookup: user_lookup
          ).call(dto)

          assert_equal false, result
          assert_instance_of Domain::Shared::Dtos::ReferenceFlagChangeDeniedFailure, received
          assert_equal "agricultural_tasks.flash.reference_flag_admin_only", received.message
          assert_equal 5, received.resource_id
          user_lookup.verify
          output_port.verify
        end

        test "同名がスコープ内に存在すると on_failure（name taken）" do
          user_id = 10
          user = domain_user_stub(id: user_id, admin: false)
          update_input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskUpdateInput.new(
            id: 5,
            name: "重複名"
          )

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [user_id])

          current = domain_record_entity_stub(user_id: user_id, is_reference: false)
          current.stubs(:reference?).returns(false)

          gateway = Object.new
          gateway.define_singleton_method(:find_by_id) { |_id| current }
          gateway.define_singleton_method(:find_by_user_id_and_name) do |user_id:, name:|
            Struct.new(:id).new(99)
          end
          gateway.define_singleton_method(:within_transaction) { |&block| block.call }
          gateway.define_singleton_method(:update) { |*| flunk "update should not be called" }

          translator = Object.new
          def translator.t(key) = key

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          result = build_interactor(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
            translator: translator,
            user_lookup: user_lookup
          ).call(update_input_dto)

          assert_equal false, result
          assert_equal "activerecord.errors.models.agricultural_task.attributes.name.taken", received.message
          user_lookup.verify
          output_port.verify
        end

        test "selected_crop_ids があるとき Policy と Gateway でテンプレート同期する" do
          user_id = 10
          user = domain_user_stub(id: user_id, admin: false)
          task_entity = Domain::AgriculturalTask::Entities::AgriculturalTaskEntity.new(
            id: 5,
            user_id: user_id,
            name: "剪定",
            description: nil,
            time_per_sqm: nil,
            weather_dependency: nil,
            required_tools: [],
            skill_level: nil,
            region: "jp",
            task_type: nil,
            is_reference: false
          )
          update_input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskUpdateInput.new(
            id: 5,
            name: "剪定",
            selected_crop_ids: [1, 2]
          )

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [user_id])

          current = domain_record_entity_stub(user_id: user_id, is_reference: false)
          current.stubs(:reference?).returns(false)

          gateway = Minitest::Mock.new
          gateway.expect(:find_by_id, current, [5])
          gateway.expect(:find_by_user_id_and_name, nil) do |**kwargs|
            kwargs[:user_id] == user_id && kwargs[:name] == "剪定"
          end
          gateway.expect(:within_transaction, nil) { |&block| block.call }
          gateway.expect(:update, task_entity) do |id, attrs|
            id == 5 && attrs[:name] == "剪定"
          end

          crop_gateway = Minitest::Mock.new
          crop_gateway.expect(:list_by_user_id, [
            stub(id: 1, user_id: user_id, is_reference: false),
            stub(id: 3, user_id: user_id, is_reference: false)
          ]) do |**kwargs|
            kwargs[:user_id] == user_id && kwargs[:region] == "jp"
          end
          crop_gateway.expect(:find_by_id, stub(id: 3), [3])

          existing_link = Domain::AgriculturalTask::Entities::CropTaskTemplateLinkEntity.new(
            id: 9,
            agricultural_task_id: 5,
            crop_id: 3
          )
          template_gateway = Minitest::Mock.new
          template_gateway.expect(:list_by_agricultural_task_id, [existing_link]) do |**kwargs|
            kwargs[:agricultural_task_id] == 5
          end
          template_gateway.expect(:find_by_agricultural_task_id_and_crop_id, nil) do |**kwargs|
            kwargs[:agricultural_task_id] == 5 && kwargs[:crop_id] == 1
          end
          template_gateway.expect(:find_by_agricultural_task_id_and_crop_id, existing_link) do |**kwargs|
            kwargs[:agricultural_task_id] == 5 && kwargs[:crop_id] == 3
          end
          template_gateway.expect(:create, nil) do |**kwargs|
            kwargs[:agricultural_task_id] == 5 && kwargs[:crop_id] == 1 && kwargs[:attrs][:name] == "剪定"
          end
          template_gateway.expect(:delete, nil) do |**kwargs|
            kwargs[:agricultural_task_id] == 5 && kwargs[:crop_id] == 3
          end

          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil, [task_entity])

          result = build_interactor(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
            crop_gateway: crop_gateway,
            crop_task_template_gateway: template_gateway,
            user_lookup: user_lookup
          ).call(update_input_dto)

          assert_equal true, result
          gateway.verify
          crop_gateway.verify
          template_gateway.verify
          user_lookup.verify
          output_port.verify
        end
      end
    end
  end
end
