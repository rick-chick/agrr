# frozen_string_literal: true

require "test_helper"

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskListInteractorTest < ActiveSupport::TestCase
        test "call passes tasks and reference tasks to output port" do
          user = mock
          tasks = [ mock ]
          refs = [ mock ]

          user_lookup = mock
          user_lookup.expects(:find).with(1).returns(user)

          gateway = mock
          gateway.expects(:list_for_index).with(
            user: user,
            is_admin: false,
            filter: nil,
            query: nil
          ).returns(tasks)
          gateway.expects(:reference_tasks_for_index).with(is_admin: false).returns(refs)

          output = mock
          output.expects(:on_success).with(tasks, reference_tasks_for_index: refs)

          interactor = AgriculturalTaskListInteractor.new(
            output_port: output,
            user_id: 1,
            gateway: gateway,
            logger: mock,
            user_lookup: user_lookup
          )
          interactor.call
        end

        test "call forwards policy permission denied to on_failure as exception" do
          user = mock
          err = Domain::Shared::Policies::PolicyPermissionDenied.new

          user_lookup = mock
          user_lookup.expects(:find).with(1).returns(user)

          gateway = mock
          gateway.expects(:list_for_index).raises(err)

          output = mock
          output.expects(:on_failure).with(err)

          interactor = AgriculturalTaskListInteractor.new(
            output_port: output,
            user_id: 1,
            gateway: gateway,
            logger: mock,
            user_lookup: user_lookup
          )
          interactor.call
        end

        test "call forwards RecordNotFound to on_failure as ErrorDto" do
          user = mock
          user_lookup = mock
          user_lookup.expects(:find).with(1).returns(user)

          gateway = mock
          gateway.expects(:list_for_index).raises(Domain::Shared::Exceptions::RecordNotFound.new("missing"))

          output = mock
          output.expects(:on_failure).with do |dto|
            assert_equal "missing", dto.message
            true
          end

          interactor = AgriculturalTaskListInteractor.new(
            output_port: output,
            user_id: 1,
            gateway: gateway,
            logger: mock,
            user_lookup: user_lookup
          )
          interactor.call
        end
      end
    end
  end
end
