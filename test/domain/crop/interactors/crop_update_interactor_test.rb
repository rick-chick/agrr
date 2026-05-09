# frozen_string_literal: true

require "test_helper"

module Domain
  module Crop
    module Interactors
      class CropUpdateInteractorTest < ActiveSupport::TestCase
        test "calls on_success when gateway returns entity" do
          user_id = 10
          user = Object.new
          crop_id = 5
          input_dto = Domain::Crop::Dtos::CropUpdateInputDto.new(crop_id: crop_id, name: "更新された名前")
          crop_entity = Object.new

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          current_entity = Object.new
          def current_entity.reference?
            false
          end

          gateway = mock
          gateway.expects(:find_authorized_for_edit).with(user, crop_id, access_filter: instance_of(Domain::Shared::ReferenceRecordAccessFilter)).returns(current_entity)
          gateway.expects(:update_for_user).with(user, crop_id, instance_of(Hash), access_filter: instance_of(Domain::Shared::ReferenceRecordAccessFilter)).returns(crop_entity)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = CropUpdateInteractor.new(
            output_port: output_port,
            gateway: gateway,
            user_id: user_id,
            translator: Object.new,
            user_lookup: user_lookup
          )

          interactor.call(input_dto)

          assert_same crop_entity, received
          user_lookup.verify
          output_port.verify
        end

        test "calls on_failure with policy exception when permission denied" do
          user_id = 10
          user = Object.new
          crop_id = 5
          input_dto = Domain::Crop::Dtos::CropUpdateInputDto.new(crop_id: crop_id, name: "変更しようとした名前")

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = Object.new
          current_entity = Object.new
          def current_entity.reference?
            false
          end
          gateway.define_singleton_method(:find_authorized_for_edit) { |_u, _id, **_kw| current_entity }
          gateway.define_singleton_method(:update_for_user) do |_u, _fid, _attrs, **_kw|
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = CropUpdateInteractor.new(
            output_port: output_port,
            gateway: gateway,
            user_id: user_id,
            translator: Object.new,
            user_lookup: user_lookup
          )

          interactor.call(input_dto)

          assert_instance_of Domain::Shared::Policies::PolicyPermissionDenied, received
          user_lookup.verify
          output_port.verify
        end

        test "calls on_failure with error dto when non-admin toggles is_reference" do
          user_id = 10
          user = Object.new
          def user.admin?
            false
          end
          crop_id = 5
          msg = I18n.t("crops.flash.reference_flag_admin_only")
          input_dto = Domain::Crop::Dtos::CropUpdateInputDto.new(crop_id: crop_id, is_reference: true)

          current_entity = Object.new
          def current_entity.reference?
            false
          end

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = Object.new
          gateway.define_singleton_method(:find_authorized_for_edit) { |_u, _id, **_kw| current_entity }

          translator = Minitest::Mock.new
          translator.expect(:t, msg, [ "crops.flash.reference_flag_admin_only" ])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = CropUpdateInteractor.new(
            output_port: output_port,
            gateway: gateway,
            user_id: user_id,
            translator: translator,
            user_lookup: user_lookup
          )

          interactor.call(input_dto)

          assert_instance_of Domain::Shared::Dtos::ErrorDto, received
          assert_equal msg, received.message
          user_lookup.verify
          translator.verify
          output_port.verify
        end
      end
    end
  end
end
