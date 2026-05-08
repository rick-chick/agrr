# frozen_string_literal: true

require "test_helper"

module Domain
  module Pesticide
    module Interactors
      class PesticideCreateInteractorTest < ActiveSupport::TestCase
        test "calls on_failure with policy exception when permission denied" do
          user_id = 10
          user = Object.new
          input_dto = Domain::Pesticide::Dtos::PesticideCreateInputDto.new(name: "X", crop_id: 1, pest_id: 2)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = Object.new
          gateway.define_singleton_method(:create_for_user) { |_u, _attrs| raise Domain::Shared::Policies::PolicyPermissionDenied }

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = PesticideCreateInteractor.new(
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

        test "calls on_failure with ErrorDto when non-admin requests reference pesticide" do
          user_id = 10
          user = Object.new
          user.define_singleton_method(:admin?) { false }
          input_dto = Domain::Pesticide::Dtos::PesticideCreateInputDto.new(
            name: "参照農薬",
            active_ingredient: "X",
            crop_id: 1,
            pest_id: 2,
            is_reference: true
          )

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = Minitest::Mock.new

          translator = Minitest::Mock.new
          translator.expect(:t, "reference only", [ "pesticides.flash.reference_only_admin" ])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = PesticideCreateInteractor.new(
            output_port: output_port,
            gateway: gateway,
            user_id: user_id,
            translator: translator,
            user_lookup: user_lookup
          )

          interactor.call(input_dto)

          assert_instance_of Domain::Shared::Dtos::ErrorDto, received
          assert_equal "reference only", received.message
          user_lookup.verify
          translator.verify
          output_port.verify
        end
      end
    end
  end
end
