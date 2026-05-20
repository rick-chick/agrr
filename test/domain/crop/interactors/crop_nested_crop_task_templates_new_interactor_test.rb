# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropNestedCropTaskTemplatesNewInteractorTest < DomainLibTestCase
        setup do
          @gateway = mock
          @output_port = mock
          @user_lookup = mock
          @interactor = CropNestedCropTaskTemplatesNewInteractor.new(
            output_port: @output_port,
            gateway: @gateway,
            user_lookup: @user_lookup
          )
        end

        test "calls on_success with picklist rows" do
          input_dto = Domain::Crop::Dtos::CropNestedCropTaskTemplatesNewInput.new(user_id: 1, crop_id: 2)
          user = mock
          rows = [ { id: 9, name: "Task A" } ]

          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:selectable_agricultural_task_picklist_rows_for_nested_templates).with(user: user, crop_id: 2, access_filter: anything).returns(rows)
          @output_port.expects(:on_success).with(rows)

          @interactor.call(input_dto)
        end

        test "calls on_failure when gateway raises RecordNotFound" do
          input_dto = Domain::Crop::Dtos::CropNestedCropTaskTemplatesNewInput.new(user_id: 1, crop_id: 2)
          user = mock

          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:selectable_agricultural_task_picklist_rows_for_nested_templates).with(user: user, crop_id: 2, access_filter: anything).raises(
            Domain::Shared::Exceptions::RecordNotFound
          )
          @output_port.expects(:on_failure).with do |failure_dto|
            assert_equal :crop_not_found, failure_dto.reason
            true
          end

          @interactor.call(input_dto)
        end
      end
    end
  end
end
