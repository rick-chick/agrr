# frozen_string_literal: true

require "test_helper"

module Domain
  module Farm
    module Interactors
      class FarmUpdateInteractorTest < ActiveSupport::TestCase
        test "calls on_success when gateway returns entity" do
          user_id = 10
          user = Object.new
          farm_id = 5
          input_dto = Domain::Farm::Dtos::FarmUpdateInputDto.new(farm_id: farm_id, name: "N")
          farm_entity = Object.new

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = Minitest::Mock.new
          gateway.expect(:update_for_user, farm_entity, [ user, farm_id, { name: "N" } ])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = FarmUpdateInteractor.new(
            output_port: output_port,
            gateway: gateway,
            user_id: user_id,
            translator: Object.new,
            user_lookup: user_lookup
          )

          interactor.call(input_dto)

          assert_same farm_entity, received
          user_lookup.verify
          gateway.verify
          output_port.verify
        end

        test "calls on_failure with policy exception when permission denied" do
          user_id = 10
          user = Object.new
          farm_id = 5
          input_dto = Domain::Farm::Dtos::FarmUpdateInputDto.new(farm_id: farm_id, name: "N")

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = Object.new
          gateway.define_singleton_method(:update_for_user) do |_u, _fid, _attrs|
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = FarmUpdateInteractor.new(
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
      end
    end
  end
end
