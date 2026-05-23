# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Farm
    module Interactors
      class FarmDetailInteractorTest < DomainLibTestCase
        test "calls on_success when gateway returns dto" do
          user_id = 10
          farm_id = 3
          user = stub(id: user_id, admin?: false)
          farm_entity = stub(is_reference: false, user_id: user_id)
          dto = Object.new

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          gateway.expects(:find_by_id).with(farm_id).returns(farm_entity)
          gateway.expects(:farm_detail_with_fields).with(farm_id).returns(dto)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = FarmDetailInteractor.new(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
            translator: Object.new,
            user_lookup: user_lookup
          )

          interactor.call(farm_id)

          assert_equal dto, received
          user_lookup.verify
          output_port.verify
        end

        test "calls on_failure with policy exception when permission denied" do
          user_id = 10
          farm_id = 3
          user = stub(id: user_id, admin?: false)
          farm_entity = stub(is_reference: false, user_id: 99)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          gateway.expects(:find_by_id).with(farm_id).returns(farm_entity)
          gateway.expects(:farm_detail_with_fields).never

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = FarmDetailInteractor.new(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
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
