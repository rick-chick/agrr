# frozen_string_literal: true

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
          @gateway.expects(:find_user_non_reference_crop_for_masters!).with(user, 2).returns(crop_record)
          @gateway.expects(:masters_crop_agricultural_task_templates_index_rows).with(user: user, crop_id: 2).returns(rows)
          @output_port.expects(:on_success).with(rows)

          @interactor.call(input_dto)
        end

        test "should return crop_not_found when gateway raises RecordNotFound" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateIndexInput.new(user_id: 1, crop_id: 2)
          user = stub(id: 1, admin?: false)

          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:find_user_non_reference_crop_for_masters!).with(user, 2).raises(
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
