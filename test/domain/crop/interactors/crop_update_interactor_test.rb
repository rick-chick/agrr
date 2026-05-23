# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropUpdateInteractorTest < DomainLibTestCase
        test "calls on_success when gateway returns entity" do
          user_id = 10
          user = stub(id: user_id, admin?: false)
          crop_id = 5
          input_dto = Domain::Crop::Dtos::CropUpdateInput.new(crop_id: crop_id, name: "更新された名前")
          crop_entity = Object.new

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          current_entity = stub(reference?: false, is_reference: false, user_id: user_id)

          gateway = mock
          gateway.expects(:find_by_id).with(crop_id).returns(current_entity)
          gateway.expects(:update_for_user).with(user, crop_id, instance_of(Hash)).returns(crop_entity)

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
          user = stub(id: user_id, admin?: false)
          crop_id = 5
          input_dto = Domain::Crop::Dtos::CropUpdateInput.new(crop_id: crop_id, name: "変更しようとした名前")

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          current_entity = stub(reference?: false, is_reference: false, user_id: 99)

          gateway = Object.new
          gateway.define_singleton_method(:find_by_id) { |_id| current_entity }
          gateway.define_singleton_method(:update_for_user) { |*| flunk "update_for_user should not be called" }

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
          user = stub(id: user_id, admin?: false)
          crop_id = 5
          msg = I18n.t("crops.flash.reference_flag_admin_only")
          input_dto = Domain::Crop::Dtos::CropUpdateInput.new(crop_id: crop_id, is_reference: true)

          current_entity = stub(reference?: false, is_reference: false, user_id: user_id)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = Object.new
          gateway.define_singleton_method(:find_by_id) { |_id| current_entity }

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

          assert_instance_of Domain::Shared::Dtos::ReferenceFlagChangeDeniedFailure, received
          assert_equal msg, received.message
          assert_equal crop_id, received.resource_id
          user_lookup.verify
          translator.verify
          output_port.verify
        end
      end
    end
  end
end
