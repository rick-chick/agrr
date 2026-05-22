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

        test "一般ユーザーが is_reference フラグを変更しようとすると on_failure（reference_flag_admin_only）" do
          user = stub(id: 10, admin?: false)
          dto = Domain::InteractionRule::Dtos::InteractionRuleUpdateInput.new(id: 9, is_reference: true)

          user_lookup = mock
          user_lookup.expects(:find).with(10).returns(user)

          translator = Object.new
          def translator.t(key) = key

          gateway = mock
          gateway.expects(:find_authorized_for_edit).returns(stub(reference?: false))
          gateway.expects(:update_for_user).never

          received = nil
          output_port = mock
          output_port.expects(:on_failure).with { |arg| received = arg; true }

          InteractionRuleUpdateInteractor.new(
            output_port: output_port,
            user_id: 10,
            gateway: gateway,
            translator: translator,
            user_lookup: user_lookup
          ).call(dto)

          assert_equal "interaction_rules.flash.reference_flag_admin_only", received.message
        end

        test "admin の region 更新は Policy により保持される" do
          user = stub(id: 10, admin?: true)
          dto = Domain::InteractionRule::Dtos::InteractionRuleUpdateInput.new(id: 9, region: "us")

          user_lookup = mock
          user_lookup.expects(:find).with(10).returns(user)

          gateway = mock
          gateway.expects(:find_authorized_for_edit).returns(stub(reference?: false))
          gateway.expects(:update_for_user).with do |_user, _id, normalized, **|
            assert_equal "us", normalized[:region]
            true
          end.returns(Object.new)

          output_port = mock
          output_port.expects(:on_success)

          InteractionRuleUpdateInteractor.new(
            output_port: output_port,
            user_id: 10,
            gateway: gateway,
            translator: Object.new,
            user_lookup: user_lookup
          ).call(dto)
        end

        test "一般ユーザーの region 更新は Policy により破棄される" do
          user = stub(id: 10, admin?: false)
          dto = Domain::InteractionRule::Dtos::InteractionRuleUpdateInput.new(id: 9, region: "us")

          user_lookup = mock
          user_lookup.expects(:find).with(10).returns(user)

          gateway = mock
          gateway.expects(:find_authorized_for_edit).returns(stub(reference?: false))
          gateway.expects(:update_for_user).with do |_user, _id, normalized, **|
            assert_not normalized.key?(:region)
            true
          end.returns(Object.new)

          output_port = mock
          output_port.expects(:on_success)

          InteractionRuleUpdateInteractor.new(
            output_port: output_port,
            user_id: 10,
            gateway: gateway,
            translator: Object.new,
            user_lookup: user_lookup
          ).call(dto)
        end
      end
    end
  end
end
