# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Farm
    module Interactors
      class FarmCreateInteractorTest < DomainLibTestCase
        def build_user(id: 10)
          user = Object.new
          user.define_singleton_method(:id) { id }
          user.define_singleton_method(:admin?) { false }
          user
        end

        test "calls on_success when under farm limit" do
          user = build_user
          user_id = user.id
          input_dto = Domain::Farm::Dtos::FarmCreateInput.new(
            name: "新規農場",
            region: nil,
            latitude: 35.0,
            longitude: 135.0
          )
          farm_entity = Object.new

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          gateway.expects(:count_user_owned_non_reference_farms).with(user_id: user_id).returns(3)
          gateway.expects(:create_for_user).with(user, instance_of(Hash)).returns(farm_entity)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = FarmCreateInteractor.new(
            output_port: output_port,
            gateway: gateway,
            user_id: user_id,
            translator: Object.new,
            user_lookup: user_lookup
          )

          interactor.call(input_dto)

          assert_same farm_entity, received
          user_lookup.verify
          output_port.verify
        end

        test "calls on_failure with limit exceeded dto when at farm limit" do
          user = build_user
          user_id = user.id
          input_dto = Domain::Farm::Dtos::FarmCreateInput.new(
            name: "5件目",
            region: nil,
            latitude: 35.0,
            longitude: 135.0
          )
          msg = I18n.t("activerecord.errors.models.farm.attributes.user.farm_limit_exceeded")

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          translator = Minitest::Mock.new
          translator.expect(
            :t,
            msg,
            [ "activerecord.errors.models.farm.attributes.user.farm_limit_exceeded" ]
          )

          gateway = mock
          gateway.expects(:count_user_owned_non_reference_farms).with(user_id: user_id).returns(4)
          gateway.expects(:create_for_user).never

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = FarmCreateInteractor.new(
            output_port: output_port,
            gateway: gateway,
            user_id: user_id,
            translator: translator,
            user_lookup: user_lookup
          )

          interactor.call(input_dto)

          assert_instance_of Domain::Farm::Dtos::FarmCreateLimitExceededFailure, received
          assert_equal msg, received.message
          user_lookup.verify
          translator.verify
          output_port.verify
        end
      end
    end
  end
end
