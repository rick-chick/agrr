# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module InteractionRule
    module Interactors
      class InteractionRuleDetailInteractorTest < DomainLibTestCase
        test "calls on_failure with policy exception when permission denied" do
          user_id = 10
          rule_id = 3
          user = Object.new

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          gateway.expects(:find_authorized_for_view).with(
            user,
            rule_id,
            access_filter: instance_of(Domain::Shared::ReferenceRecordAccessFilter)
          ).raises(Domain::Shared::Policies::PolicyPermissionDenied)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          InteractionRuleDetailInteractor.new(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
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
