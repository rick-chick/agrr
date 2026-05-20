# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module InteractionRule
    module Interactors
      class InteractionRuleListInteractorTest < DomainLibTestCase
        test "call passes partitioned rules to output port on success" do
          user = Object.new
          def user.id; 1; end
          def user.admin?; false; end
          user_lookup = mock
          user_lookup.expects(:find).with(1).returns(user)

          ref = mock
          ref.expects(:is_reference).twice.returns(true)
          owned = mock
          owned.expects(:is_reference).twice.returns(false)

          expected_filter = Domain::Shared::Policies::InteractionRulePolicy.index_list_filter(user)
          gateway = mock
          gateway.expects(:list_index_for_filter).with(expected_filter).returns([ ref, owned ])

          output = mock
          output.expects(:on_success).with(
            interaction_rules: [ owned ],
            reference_rules: [ ref ]
          )

          InteractionRuleListInteractor.new(
            output_port: output,
            user_id: 1,
            gateway: gateway,
            user_lookup: user_lookup
          ).call
        end

        test "forwards policy permission denied to on_failure as exception" do
          user = Object.new
          def user.id; 1; end
          def user.admin?; false; end
          err = Domain::Shared::Policies::PolicyPermissionDenied.new

          user_lookup = mock
          user_lookup.expects(:find).with(1).returns(user)

          expected_filter = Domain::Shared::Policies::InteractionRulePolicy.index_list_filter(user)
          gateway = mock
          gateway.expects(:list_index_for_filter).with(expected_filter).raises(err)

          output = mock
          output.expects(:on_failure).with(err)

          InteractionRuleListInteractor.new(
            output_port: output,
            user_id: 1,
            gateway: gateway,
            user_lookup: user_lookup
          ).call
        end
      end
    end
  end
end
