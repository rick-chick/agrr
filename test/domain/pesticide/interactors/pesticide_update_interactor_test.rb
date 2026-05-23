# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pesticide
    module Interactors
      class PesticideUpdateInteractorTest < DomainLibTestCase
        test "calls on_failure with policy exception when permission denied" do
          user_id = 10
          user = domain_user_stub(id: user_id, admin: false)
          input_dto = Domain::Pesticide::Dtos::PesticideUpdateInput.new(pesticide_id: 5, name: "Y")

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          current = domain_record_entity_stub(user_id: 99, is_reference: false)

          gateway = mock
          gateway.expects(:find_by_id).with(5).returns(current)
          gateway.expects(:update_for_user).never

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = PesticideUpdateInteractor.new(
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

        test "calls on_failure with Error when non-admin toggles is_reference" do
          user_id = 10
          user = Object.new
          user.define_singleton_method(:admin?) { false }
          user.define_singleton_method(:id) { user_id }
          input_dto = Domain::Pesticide::Dtos::PesticideUpdateInput.new(pesticide_id: 5, is_reference: true)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          current_entity = Object.new
          current_entity.define_singleton_method(:is_reference) { false }
          current_entity.define_singleton_method(:user_id) { user_id }

          gateway = mock
          gateway.expects(:find_by_id).with(5).returns(current_entity)

          translator = Minitest::Mock.new
          translator.expect(:t, "flag admin only", [ "pesticides.flash.reference_flag_admin_only" ])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = PesticideUpdateInteractor.new(
            output_port: output_port,
            gateway: gateway,
            user_id: user_id,
            translator: translator,
            user_lookup: user_lookup
          )

          interactor.call(input_dto)

          assert_instance_of Domain::Shared::Dtos::ReferenceFlagChangeDeniedFailure, received
          assert_equal 5, received.resource_id
          assert_equal "flag admin only", received.message
          user_lookup.verify
          translator.verify
          output_port.verify
        end
      end
    end
  end
end
