# frozen_string_literal: true

require "test_helper"

module Domain
  module Farm
    module Interactors
      class FarmDetailInteractorTest < ActiveSupport::TestCase
        test "calls on_success when gateway returns dto" do
          user_id = 10
          farm_id = 3
          user = Object.new
          dto = Object.new

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = Minitest::Mock.new
          gateway.expect(:detail_for_authorized_view, dto, [ user, farm_id ])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = FarmDetailInteractor.new(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
            logger: Object.new,
            translator: Object.new,
            user_lookup: user_lookup
          )

          interactor.call(farm_id)

          assert_equal dto, received
          user_lookup.verify
          gateway.verify
          output_port.verify
        end

        test "calls on_failure with policy exception when permission denied" do
          user_id = 10
          farm_id = 3
          user = Object.new

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = Object.new
          gateway.define_singleton_method(:detail_for_authorized_view) do |_u, _fid|
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = FarmDetailInteractor.new(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
            logger: Object.new,
            translator: Object.new,
            user_lookup: user_lookup
          )

          interactor.call(farm_id)

          assert_instance_of Domain::Shared::Policies::PolicyPermissionDenied, received
          user_lookup.verify
          output_port.verify
        end
      end
    end
  end
end
