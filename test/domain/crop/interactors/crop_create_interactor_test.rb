# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropCreateInteractorTest < DomainLibTestCase
        test "calls on_success when gateway returns entity" do
          user_id = 10
          user = Object.new
          def user.admin?
            false
          end
          def user.id
            10
          end
          input_dto = Domain::Crop::Dtos::CropCreateInput.new(name: "新規作物", variety: "品種")
          crop_entity = Object.new

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          gateway.expects(:count_user_owned_non_reference_crops).with(user_id: user_id).returns(0)
          gateway.expects(:create_for_user).with(user, instance_of(Hash)).returns(crop_entity)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = CropCreateInteractor.new(
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

        test "calls on_failure with error dto when non-admin requests reference crop" do
          user_id = 10
          user = Object.new
          def user.admin?
            false
          end
          msg = I18n.t("crops.flash.reference_only_admin")
          input_dto = Domain::Crop::Dtos::CropCreateInput.new(name: "参照のみ", is_reference: true)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          translator = Minitest::Mock.new
          translator.expect(:t, msg, [ "crops.flash.reference_only_admin" ])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = CropCreateInteractor.new(
            output_port: output_port,
            gateway: Object.new,
            user_id: user_id,
            translator: translator,
            user_lookup: user_lookup
          )

          interactor.call(input_dto)

          assert_instance_of Domain::Shared::Dtos::Error, received
          assert_equal msg, received.message
          user_lookup.verify
          translator.verify
          output_port.verify
        end

        test "calls on_failure with limit exceeded dto when at crop limit" do
          user_id = 10
          user = Object.new
          def user.admin?
            false
          end
          def user.id
            10
          end
          input_dto = Domain::Crop::Dtos::CropCreateInput.new(name: "21件目", variety: "品種")
          msg = I18n.t("activerecord.errors.models.crop.attributes.user.crop_limit_exceeded")

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          translator = Minitest::Mock.new
          translator.expect(
            :t,
            msg,
            [ "activerecord.errors.models.crop.attributes.user.crop_limit_exceeded" ]
          )

          gateway = mock
          gateway.expects(:count_user_owned_non_reference_crops).with(user_id: user_id).returns(20)
          gateway.expects(:create_for_user).never

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = CropCreateInteractor.new(
            output_port: output_port,
            gateway: gateway,
            user_id: user_id,
            translator: translator,
            user_lookup: user_lookup
          )

          interactor.call(input_dto)

          assert_instance_of Domain::Crop::Dtos::CropCreateLimitExceededFailure, received
          assert_equal msg, received.message
          user_lookup.verify
          translator.verify
          output_port.verify
        end

        test "skips crop limit check for reference crop create by admin" do
          user_id = 1
          user = Object.new
          def user.admin?
            true
          end
          def user.id
            1
          end
          input_dto = Domain::Crop::Dtos::CropCreateInput.new(name: "参照作物", is_reference: true)
          crop_entity = Object.new

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          gateway.expects(:count_user_owned_non_reference_crops).never
          gateway.expects(:create_for_user).with(user, instance_of(Hash)).returns(crop_entity)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = CropCreateInteractor.new(
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
      end
    end
  end
end
