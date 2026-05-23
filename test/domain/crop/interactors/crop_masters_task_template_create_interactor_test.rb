# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropMastersTaskTemplateCreateInteractorTest < DomainLibTestCase
        setup do
          @gateway = mock
          @agricultural_task_gateway = mock
          @output_port = mock
          @user_lookup = mock
          @interactor = CropMastersTaskTemplateCreateInteractor.new(
            output_port: @output_port,
            gateway: @gateway,
            user_lookup: @user_lookup,
            agricultural_task_gateway: @agricultural_task_gateway
          )
        end

        test "should create association successfully" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInput.new(
            user_id: 1,
            crop_id: 2,
            agricultural_task_id: 3
          )
          user = stub(id: 1, admin?: false)
          crop_record = stub(is_reference: false, user_id: 1)
          task_entity = stub(is_reference: false, user_id: 1)
          template_dto = mock
          result = Domain::Crop::Dtos::MastersCropTaskTemplateCreateOutput.new(template: template_dto)

          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:find_user_non_reference_crop_for_masters!).with(user, 2).returns(crop_record)
          @agricultural_task_gateway.expects(:find_by_id).with(3).returns(task_entity)
          @gateway.expects(:create_masters_crop_task_template_association).with(user, input_dto).returns(result)
          @output_port.expects(:on_success).with(template_dto)

          @interactor.call(input_dto)
        end

        test "should return failure when agricultural_task_id missing" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInput.new(
            user_id: 1,
            crop_id: 2,
            agricultural_task_id: nil
          )

          @user_lookup.expects(:find).never
          @gateway.expects(:find_user_non_reference_crop_for_masters!).never
          @agricultural_task_gateway.expects(:find_by_id).never
          @gateway.expects(:create_masters_crop_task_template_association).never
          @output_port.expects(:on_failure).with do |failure_dto|
            assert_equal :missing_agricultural_task_id, failure_dto.reason
            true
          end

          @interactor.call(input_dto)
        end

        test "should return failure when agricultural task not found" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInput.new(
            user_id: 1,
            crop_id: 2,
            agricultural_task_id: 3
          )
          user = stub(id: 1, admin?: false)
          crop_record = stub(is_reference: false, user_id: 1)

          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:find_user_non_reference_crop_for_masters!).with(user, 2).returns(crop_record)
          @agricultural_task_gateway.expects(:find_by_id).with(3).raises(
            Domain::Shared::Exceptions::RecordNotFound
          )
          @gateway.expects(:create_masters_crop_task_template_association).never
          @output_port.expects(:on_failure).with do |failure_dto|
            assert_equal :agricultural_task_not_found, failure_dto.reason
            true
          end

          @interactor.call(input_dto)
        end

        test "should return failure when association is forbidden" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInput.new(
            user_id: 1,
            crop_id: 2,
            agricultural_task_id: 3
          )
          user = stub(id: 1, admin?: false)
          crop_record = stub(is_reference: false, user_id: 1)
          task_entity = stub(is_reference: false, user_id: 99)

          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:find_user_non_reference_crop_for_masters!).with(user, 2).returns(crop_record)
          @agricultural_task_gateway.expects(:find_by_id).with(3).returns(task_entity)
          @gateway.expects(:create_masters_crop_task_template_association).never
          @output_port.expects(:on_failure).with do |failure_dto|
            assert_equal :forbidden, failure_dto.reason
            true
          end

          @interactor.call(input_dto)
        end

        test "should return failure when association is duplicate" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInput.new(
            user_id: 1,
            crop_id: 2,
            agricultural_task_id: 3
          )
          user = stub(id: 1, admin?: false)
          crop_record = stub(is_reference: false, user_id: 1)
          task_entity = stub(is_reference: false, user_id: 1)
          failure = Domain::Crop::Dtos::MastersCropTaskTemplateCreateFailure.new(
            reason: :duplicate
          )
          result = Domain::Crop::Dtos::MastersCropTaskTemplateCreateOutput.new(failure: failure)

          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:find_user_non_reference_crop_for_masters!).with(user, 2).returns(crop_record)
          @agricultural_task_gateway.expects(:find_by_id).with(3).returns(task_entity)
          @gateway.expects(:create_masters_crop_task_template_association).with(user, input_dto).returns(result)
          @output_port.expects(:on_failure).with(failure)

          @interactor.call(input_dto)
        end

        test "should return failure when validation fails" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInput.new(
            user_id: 1,
            crop_id: 2,
            agricultural_task_id: 3
          )
          user = stub(id: 1, admin?: false)
          crop_record = stub(is_reference: false, user_id: 1)
          task_entity = stub(is_reference: false, user_id: 1)
          record_invalid = Domain::Shared::Exceptions::RecordInvalid.new(
            "invalid",
            errors: [ "Name can't be blank" ]
          )

          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:find_user_non_reference_crop_for_masters!).with(user, 2).returns(crop_record)
          @agricultural_task_gateway.expects(:find_by_id).with(3).returns(task_entity)
          @gateway.expects(:create_masters_crop_task_template_association).with(user, input_dto).raises(record_invalid)
          @output_port.expects(:on_failure).with do |failure_dto|
            assert_equal :validation_failed, failure_dto.reason
            assert_equal [ "Name can't be blank" ], failure_dto.errors
            true
          end

          @interactor.call(input_dto)
        end
      end
    end
  end
end
