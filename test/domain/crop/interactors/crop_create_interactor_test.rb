# frozen_string_literal: true

require "test_helper"

module Domain
  module Crop
    module Interactors
      class CropCreateInteractorTest < ActiveSupport::TestCase
        test "calls on_success when gateway returns entity" do
          user_id = 10
          user = Object.new
          def user.admin?
            false
          end
          input_dto = Domain::Crop::Dtos::CropCreateInputDto.new(name: "新規作物", variety: "品種")
          crop_entity = Object.new

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = Minitest::Mock.new
          gateway.expect(
            :create_for_user,
            crop_entity,
            [
              user,
              {
                name: "新規作物",
                variety: "品種",
                area_per_unit: nil,
                revenue_per_area: nil,
                region: nil,
                groups: [],
                is_reference: false
              }
            ]
          )

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
          gateway.verify
          output_port.verify
        end

        test "calls on_failure with error dto when non-admin requests reference crop" do
          user_id = 10
          user = Object.new
          def user.admin?
            false
          end
          msg = I18n.t("crops.flash.reference_only_admin")
          input_dto = Domain::Crop::Dtos::CropCreateInputDto.new(name: "参照のみ", is_reference: true)

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
