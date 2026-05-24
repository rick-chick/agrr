# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pesticide
    module Interactors
      class PesticideDetailInteractorTest < DomainLibTestCase
        test "calls on_success with detail dto when view is allowed" do
          user_id = 10
          pesticide_id = 3
          user = stub(id: user_id, admin?: false)
          pesticide_entity = stub(is_reference: false, user_id: user_id)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          detail_dto = stub(
            pesticide: pesticide_entity,
            crop_name: "トマト",
            pest_name: "アブラムシ",
            usage_constraint_snapshot: :usage,
            application_detail_snapshot: :application
          )
          gateway.expects(:find_pesticide_show_detail).with(pesticide_id).returns(detail_dto)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = PesticideDetailInteractor.new(
            output_port: output_port,
            gateway: gateway,
            user_id: user_id,
            user_lookup: user_lookup
          )

          interactor.call(pesticide_id)

          assert_instance_of Domain::Pesticide::Dtos::PesticideDetailOutput, received
          assert_equal pesticide_entity, received.pesticide
          assert_equal "トマト", received.crop_name
          assert_equal "アブラムシ", received.pest_name
          assert_equal :usage, received.usage_constraint_snapshot
          assert_equal :application, received.application_detail_snapshot
          user_lookup.verify
          output_port.verify
        end

        test "calls on_failure with policy exception when reference pesticide is not visible" do
          user_id = 10
          pesticide_id = 3
          user = stub(id: user_id, admin?: false)
          pesticide_entity = stub(is_reference: true, user_id: nil)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          detail_dto = stub(pesticide: pesticide_entity)
          gateway.expects(:find_pesticide_show_detail).with(pesticide_id).returns(detail_dto)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = PesticideDetailInteractor.new(
            output_port: output_port,
            gateway: gateway,
            user_id: user_id,
            user_lookup: user_lookup
          )

          interactor.call(pesticide_id)

          assert_instance_of Domain::Shared::Policies::PolicyPermissionDenied, received
          user_lookup.verify
          output_port.verify
        end

        test "calls on_failure with policy exception when other user pesticide" do
          user_id = 10
          pesticide_id = 3
          user = stub(id: user_id, admin?: false)
          pesticide_entity = stub(is_reference: false, user_id: 99)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          detail_dto = stub(pesticide: pesticide_entity)
          gateway.expects(:find_pesticide_show_detail).with(pesticide_id).returns(detail_dto)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = PesticideDetailInteractor.new(
            output_port: output_port,
            gateway: gateway,
            user_id: user_id,
            user_lookup: user_lookup
          )

          interactor.call(pesticide_id)

          assert_instance_of Domain::Shared::Policies::PolicyPermissionDenied, received
          user_lookup.verify
          output_port.verify
        end
      end
    end
  end
end
