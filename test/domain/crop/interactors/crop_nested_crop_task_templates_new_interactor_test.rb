# frozen_string_literal: true

# 作物編集認可の拒否・欠損は CropMastersCropEditAccessTest で表明。
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
          user = stub(id: 1, admin?: false)
          crop_record = stub(is_reference: false, user_id: 1)
          rows = [ { id: 9, name: "Task A" } ]

          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:find_by_id).with(2).returns(crop_record)
          @gateway.expects(:selectable_agricultural_task_picklist_rows_for_nested_templates).with(user: user, crop_id: 2).returns(rows)
          @output_port.expects(:on_success).with(rows)

          @interactor.call(input_dto)
        end

      end
    end
  end
end
