# frozen_string_literal: true

require "test_helper"

module Domain
  module Pesticide
    module Interactors
      class PesticideUpdateInteractorTest < ActiveSupport::TestCase
        test "calls on_failure with policy exception when permission denied" do
          user_id = 10
          user = Object.new
          input_dto = Domain::Pesticide::Dtos::PesticideUpdateInputDto.new(pesticide_id: 5, name: "Y")

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = Object.new
          gateway.define_singleton_method(:update_for_user) { |_u, _id, _attrs| raise Domain::Shared::Policies::PolicyPermissionDenied }

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = PesticideUpdateInteractor.new(
            output_port: output_port,
            gateway: gateway,
            user_id: user_id,
            logger: Object.new,
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
