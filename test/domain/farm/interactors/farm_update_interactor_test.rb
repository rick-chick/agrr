# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Farm
    module Interactors
      class FarmUpdateInteractorTest < DomainLibTestCase
        test "calls on_success when gateway returns entity" do
          user_id = 10
          user = Object.new
          def user.admin? = false
          farm_id = 5
          input_dto = Domain::Farm::Dtos::FarmUpdateInput.new(farm_id: farm_id, name: "N")
          farm_entity = Object.new

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          gateway.expects(:update_for_user).with(
            user,
            farm_id,
            { name: "N" },
            access_filter: instance_of(Domain::Shared::ReferenceRecordAccessFilter)
          ).returns(farm_entity)

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
          output_port.verify
        end

        test "calls on_failure with policy exception when permission denied" do
          user_id = 10
          user = Object.new
          def user.admin? = false
          farm_id = 5
          input_dto = Domain::Farm::Dtos::FarmUpdateInput.new(farm_id: farm_id, name: "N")

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          gateway.expects(:update_for_user).with(
            user,
            farm_id,
            { name: "N" },
            access_filter: instance_of(Domain::Shared::ReferenceRecordAccessFilter)
          ).raises(Domain::Shared::Policies::PolicyPermissionDenied)

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
