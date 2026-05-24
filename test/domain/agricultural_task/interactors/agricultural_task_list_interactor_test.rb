# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskListInteractorTest < DomainLibTestCase
        test "non-admin: calls list_user_owned_tasks" do
          user = domain_user_stub(id: 1, admin: false)
          tasks = [ domain_record_entity_stub(user_id: 1) ]

          user_lookup = mock
          user_lookup.expects(:find).with(1).returns(user)

          gateway = mock
          gateway.expects(:list_user_owned_tasks).with(user_id: 1, query: nil).returns(tasks)

          output = mock
          expect_referencable_list_rows_on_success(output, tasks, page_display: true)

          interactor = AgriculturalTaskListInteractor.new(
            output_port: output,
            user_id: 1,
            gateway: gateway,
            user_lookup: user_lookup
          )
          interactor.call
        end

        test "admin with no filter (defaults to all): calls list_user_and_reference_tasks" do
          user = domain_user_stub(id: 2, admin: true)
          tasks = [ domain_record_entity_stub(user_id: 2) ]

          user_lookup = mock
          user_lookup.expects(:find).with(2).returns(user)

          gateway = mock
          gateway.expects(:list_user_and_reference_tasks).with(user_id: 2, query: nil).returns(tasks)

          output = mock
          expect_referencable_list_rows_on_success(output, tasks, page_display: true)

          input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskListInput.new(is_admin: true)
          interactor = AgriculturalTaskListInteractor.new(
            output_port: output,
            user_id: 2,
            gateway: gateway,
            user_lookup: user_lookup
          )
          interactor.call(input_dto)
        end

        test "admin filter=reference: calls list_reference_tasks" do
          user = domain_user_stub(id: 2, admin: true)
          refs = [ domain_record_entity_stub(user_id: 2, is_reference: true) ]

          user_lookup = mock
          user_lookup.expects(:find).with(2).returns(user)

          gateway = mock
          gateway.expects(:list_reference_tasks).with(query: nil).returns(refs)

          output = mock
          expect_referencable_list_rows_on_success(output, refs, page_display: true)

          input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskListInput.new(is_admin: true, filter: "reference")
          interactor = AgriculturalTaskListInteractor.new(
            output_port: output,
            user_id: 2,
            gateway: gateway,
            user_lookup: user_lookup
          )
          interactor.call(input_dto)
        end

        test "forwards policy permission denied to on_failure as exception" do
          user = mock
          user.stubs(:id).returns(1)
          err = Domain::Shared::Policies::PolicyPermissionDenied.new

          user_lookup = mock
          user_lookup.expects(:find).with(1).returns(user)

          gateway = mock
          gateway.expects(:list_user_owned_tasks).with(user_id: 1, query: nil).raises(err)

          output = mock
          output.expects(:on_failure).with(err)

          interactor = AgriculturalTaskListInteractor.new(
            output_port: output,
            user_id: 1,
            gateway: gateway,
            user_lookup: user_lookup
          )
          interactor.call
        end

        test "forwards RecordNotFound to on_failure as Error" do
          user = mock
          user.stubs(:id).returns(1)
          user_lookup = mock
          user_lookup.expects(:find).with(1).returns(user)

          gateway = mock
          gateway.expects(:list_user_owned_tasks).with(user_id: 1, query: nil).raises(Domain::Shared::Exceptions::RecordNotFound.new("missing"))

          output = mock
          output.expects(:on_failure).with do |dto|
            assert_equal "missing", dto.message
            true
          end

          interactor = AgriculturalTaskListInteractor.new(
            output_port: output,
            user_id: 1,
            gateway: gateway,
            user_lookup: user_lookup
          )
          interactor.call
        end
      end
    end
  end
end
