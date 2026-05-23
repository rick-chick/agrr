# frozen_string_literal: true

# 作物編集認可の拒否・欠損は CropMastersCropEditAccessTest で表明。
require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropMastersTaskTemplateIndexInteractorTest < DomainLibTestCase
        setup do
          @gateway = mock
          @output_port = mock
          @user_lookup = mock
          @interactor = CropMastersTaskTemplateIndexInteractor.new(
            output_port: @output_port,
            gateway: @gateway,
            user_lookup: @user_lookup
          )
        end

        test "should return rows successfully" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateIndexInput.new(user_id: 1, crop_id: 2)
          user = stub(id: 1, admin?: false)
          crop_record = stub(is_reference: false, user_id: 1)
          rows = [ { "id" => 1 } ]

          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:find_by_id).with(2).returns(crop_record)
          @gateway.expects(:masters_crop_agricultural_task_templates_index_rows).with(crop_id: 2).returns(rows)
          @output_port.expects(:on_success).with(rows)

          @interactor.call(input_dto)
        end

      end
    end
  end
end
