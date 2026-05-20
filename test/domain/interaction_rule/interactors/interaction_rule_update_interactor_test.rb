# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module InteractionRule
    module Interactors
      class InteractionRuleUpdateInteractorTest < DomainLibTestCase
        test "calls on_failure with policy exception when find_authorized_for_edit denies" do
          user_id = 10
          user = Object.new
          dto = Domain::InteractionRule::Dtos::InteractionRuleUpdateInput.new(
            id: 9,
            source_group: "変更しようとしたグループ"
          )

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          gateway.expects(:find_authorized_for_edit).with(
            user,
            9,
            access_filter: instance_of(Domain::Shared::ReferenceRecordAccessFilter)
          ).raises(Domain::Shared::Policies::PolicyPermissionDenied)
          gateway.expects(:update_for_user).never

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          InteractionRuleUpdateInteractor.new(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
            translator: Object.new,
            user_lookup: user_lookup
          ).call(dto)

          assert_instance_of Domain::Shared::Policies::PolicyPermissionDenied, received
          user_lookup.verify
          output_port.verify
        end
      end
    end
  end
end
