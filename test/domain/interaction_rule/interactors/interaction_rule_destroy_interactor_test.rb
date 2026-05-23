# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module InteractionRule
    module Interactors
      class InteractionRuleDestroyInteractorTest < DomainLibTestCase
        test "calls on_failure with policy exception when interactor denies destroy" do
          user_id = 10
          rule_id = 7
          user = stub(id: user_id, admin?: false)
          translator = Object.new
          current = stub(is_reference: false, user_id: 99)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          gateway.expects(:find_by_id).with(rule_id).returns(current)
          gateway.expects(:soft_delete_with_undo).never

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          InteractionRuleDestroyInteractor.new(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
            translator: translator,
            user_lookup: user_lookup
          ).call(rule_id)

          assert_instance_of Domain::Shared::Policies::PolicyPermissionDenied, received
          user_lookup.verify
          output_port.verify
        end
      end
    end
  end
end
