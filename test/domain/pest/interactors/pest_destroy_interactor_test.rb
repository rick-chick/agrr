# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pest
    module Interactors
      class PestDestroyInteractorTest < DomainLibTestCase
        test "calls on_success when delete is allowed" do
          user_id = 10
          pest_id = 7
          user = domain_user_stub(id: user_id, admin: false)
          undo_entity = Object.new
          pest_entity = domain_record_entity_stub(user_id: user_id, is_reference: false)
          usage = Domain::Pest::Dtos::PestDeleteUsage.new(pesticides_count: 0)
          translator = Object.new

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          gateway.expects(:find_by_id).with(pest_id).returns(pest_entity)
          gateway.expects(:find_delete_usage).with(pest_id).returns(usage)
          gateway.expects(:soft_delete_with_undo).with(
            user: user,
            pest_id: pest_id,
            auto_hide_after: 5000,
            translator: translator
          ).returns({ success: true, undo_entity: undo_entity })

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          PestDestroyInteractor.new(
            output_port: output_port,
            gateway: gateway,
            user_id: user_id,
            translator: translator,
            user_lookup: user_lookup
          ).call(pest_id)

          assert_instance_of Domain::Pest::Dtos::PestDestroyOutput, received
          assert_equal undo_entity, received.undo
          user_lookup.verify
          output_port.verify
        end

        test "calls on_failure when pesticides block delete" do
          user_id = 10
          pest_id = 7
          user = domain_user_stub(id: user_id, admin: false)
          pest_entity = domain_record_entity_stub(user_id: user_id, is_reference: false)
          usage = Domain::Pest::Dtos::PestDeleteUsage.new(pesticides_count: 2)
          translator = mock
          translator.expects(:t).with("pests.flash.cannot_delete_in_use").returns("blocked")

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          gateway.expects(:find_by_id).with(pest_id).returns(pest_entity)
          gateway.expects(:find_delete_usage).with(pest_id).returns(usage)
          gateway.expects(:soft_delete_with_undo).never

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          PestDestroyInteractor.new(
            output_port: output_port,
            gateway: gateway,
            user_id: user_id,
            translator: translator,
            user_lookup: user_lookup
          ).call(pest_id)

          assert_instance_of Domain::Shared::Dtos::Error, received
          assert_equal "blocked", received.message
          user_lookup.verify
          output_port.verify
        end

        test "calls on_failure with Error when permission denied" do
          user_id = 10
          pest_id = 7
          user = domain_user_stub(id: user_id, admin: false)
          pest_entity = domain_record_entity_stub(user_id: 99, is_reference: false)
          translator = mock
          translator.expects(:t).with("pests.flash.no_permission").returns("denied")

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          gateway.expects(:find_by_id).with(pest_id).returns(pest_entity)
          gateway.expects(:find_delete_usage).never
          gateway.expects(:soft_delete_with_undo).never

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          PestDestroyInteractor.new(
            output_port: output_port,
            gateway: gateway,
            user_id: user_id,
            translator: translator,
            user_lookup: user_lookup
          ).call(pest_id)

          assert_instance_of Domain::Shared::Dtos::Error, received
          assert_equal "denied", received.message
          user_lookup.verify
          output_port.verify
        end
      end
    end
  end
end
