# frozen_string_literal: true

require "test_helper"

module Domain
  module InteractionRule
    module Interactors
      class InteractionRuleListInteractorTest < ActiveSupport::TestCase
        test "call passes partitioned rules to output port on success" do
          user = mock
          user_lookup = mock
          user_lookup.expects(:find).with(1).returns(user)

          ref = mock
          ref.expects(:is_reference).twice.returns(true)
          owned = mock
          owned.expects(:is_reference).twice.returns(false)

          gateway = mock
          gateway.expects(:list_index_for_user).with(user).returns([ ref, owned ])

          output = mock
          output.expects(:on_success).with(
            interaction_rules: [ owned ],
            reference_rules: [ ref ]
          )

          InteractionRuleListInteractor.new(
            output_port: output,
            user_id: 1,
            gateway: gateway,
            logger: mock,
            user_lookup: user_lookup
          ).call
        end

        test "forwards policy permission denied to on_failure as exception" do
          user = mock
          err = Domain::Shared::Policies::PolicyPermissionDenied.new

          user_lookup = mock
          user_lookup.expects(:find).with(1).returns(user)

          gateway = mock
          gateway.expects(:list_index_for_user).with(user).raises(err)

          output = mock
          output.expects(:on_failure).with(err)

          InteractionRuleListInteractor.new(
            output_port: output,
            user_id: 1,
            gateway: gateway,
            logger: mock,
            user_lookup: user_lookup
          ).call
        end
      end
    end
  end
end
