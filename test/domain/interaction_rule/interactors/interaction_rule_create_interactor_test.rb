# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module InteractionRule
    module Interactors
      class InteractionRuleCreateInteractorTest < DomainLibTestCase
        def build_input(is_reference: nil, region: nil)
          Domain::InteractionRule::Dtos::InteractionRuleCreateInput.new(
            rule_type: "continuous_cultivation",
            source_group: "A",
            target_group: "B",
            impact_ratio: 1.0,
            region: region,
            is_reference: is_reference
          )
        end

        def build_interactor(output_port:, gateway:, user:)
          user_lookup = mock
          user_lookup.expects(:find).with(7).returns(user)
          translator = Object.new
          def translator.t(key) = key
          InteractionRuleCreateInteractor.new(
            output_port: output_port,
            user_id: 7,
            gateway: gateway,
            translator: translator,
            user_lookup: user_lookup
          )
        end

        test "一般ユーザーが参照ルールを作成しようとすると on_failure（reference_only_admin）" do
          gateway = mock
          gateway.expects(:create_for_user).never
          output_port = mock
          received = nil
          output_port.expects(:on_failure).with { |arg| received = arg; true }

          build_interactor(output_port: output_port, gateway: gateway, user: stub(id: 7, admin?: false))
            .call(build_input(is_reference: true))

          assert_equal "interaction_rules.flash.reference_only_admin", received.message
        end

        test "admin は参照ルールを作成でき on_success" do
          rule_entity = Object.new
          gateway = mock
          gateway.expects(:create_for_user).with do |user, attrs|
            assert attrs[:is_reference]
            assert_nil attrs[:user_id]
            true
          end.returns(rule_entity)
          output_port = mock
          output_port.expects(:on_success).with(rule_entity)

          build_interactor(output_port: output_port, gateway: gateway, user: stub(id: 7, admin?: true))
            .call(build_input(is_reference: true))
        end

        test "一般ユーザーの非参照ルール作成は呼び出しユーザー所有で on_success" do
          rule_entity = Object.new
          gateway = mock
          gateway.expects(:create_for_user).with do |user, attrs|
            assert_not attrs[:is_reference]
            assert_equal 7, attrs[:user_id]
            true
          end.returns(rule_entity)
          output_port = mock
          output_port.expects(:on_success).with(rule_entity)

          build_interactor(output_port: output_port, gateway: gateway, user: stub(id: 7, admin?: false))
            .call(build_input(is_reference: false))
        end

        test "一般ユーザーの region 指定は Policy により破棄される" do
          gateway = mock
          gateway.expects(:create_for_user).with do |user, attrs|
            assert_not attrs.key?(:region)
            true
          end.returns(Object.new)
          output_port = mock
          output_port.expects(:on_success)

          build_interactor(output_port: output_port, gateway: gateway, user: stub(id: 7, admin?: false))
            .call(build_input(is_reference: false, region: "us"))
        end

        test "admin の region 指定は保持される" do
          gateway = mock
          gateway.expects(:create_for_user).with do |user, attrs|
            assert_equal "us", attrs[:region]
            true
          end.returns(Object.new)
          output_port = mock
          output_port.expects(:on_success)

          build_interactor(output_port: output_port, gateway: gateway, user: stub(id: 7, admin?: true))
            .call(build_input(is_reference: false, region: "us"))
        end
      end
    end
  end
end
