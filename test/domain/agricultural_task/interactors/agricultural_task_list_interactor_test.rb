# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskListInteractorTest < DomainLibTestCase
        test "non-admin: calls list_for_index and passes tasks" do
          user = mock
          user.stubs(:id).returns(1)
          tasks = [ mock ]

          user_lookup = mock
          user_lookup.expects(:find).with(1).returns(user)

          gateway = mock
          gateway.expects(:list_for_index).with(user: user, is_admin: false, filter: "user", query: nil).returns(tasks)

          output = mock
          output.expects(:on_success).with(tasks)

          interactor = AgriculturalTaskListInteractor.new(
            output_port: output,
            user_id: 1,
            gateway: gateway,
            user_lookup: user_lookup
          )
          interactor.call
        end

        test "admin with no filter (defaults to all): calls list_for_index" do
          user = mock
          user.stubs(:id).returns(2)
          tasks = [ mock ]

          user_lookup = mock
          user_lookup.expects(:find).with(2).returns(user)

          gateway = mock
          gateway.expects(:list_for_index).with(user: user, is_admin: true, filter: "all", query: nil).returns(tasks)

          output = mock
          output.expects(:on_success).with(tasks)

          input_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskListInput.new(is_admin: true)
          interactor = AgriculturalTaskListInteractor.new(
            output_port: output,
            user_id: 2,
            gateway: gateway,
            user_lookup: user_lookup
          )
          interactor.call(input_dto)
        end

        test "admin filter=reference: calls list_for_index for filtered tasks" do
          user = mock
          user.stubs(:id).returns(2)
          refs = [ mock ]

          user_lookup = mock
          user_lookup.expects(:find).with(2).returns(user)

          gateway = mock
          gateway.expects(:list_for_index).with(user: user, is_admin: true, filter: "reference", query: nil).returns(refs)

          output = mock
          output.expects(:on_success).with(refs)

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
          gateway.expects(:list_for_index).with(user: user, is_admin: false, filter: "user", query: nil).raises(err)

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
          gateway.expects(:list_for_index).with(user: user, is_admin: false, filter: "user", query: nil).raises(Domain::Shared::Exceptions::RecordNotFound.new("missing"))

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
