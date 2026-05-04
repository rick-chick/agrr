# frozen_string_literal: true

require "test_helper"

module Domain
  module Crop
    module Interactors
      class CropMastersTaskTemplateCreateInteractorTest < ActiveSupport::TestCase
        setup do
          @gateway = mock
          @output_port = mock
          @user_lookup = mock
          @interactor = CropMastersTaskTemplateCreateInteractor.new(
            output_port: @output_port,
            gateway: @gateway,
            user_lookup: @user_lookup
          )
        end

        test "should create association successfully" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInputDto.new(
            user_id: 1,
            crop_id: 2,
            agricultural_task_id: 3
          )
          user = mock
          template_dto = mock
          result = Domain::Crop::Dtos::MastersCropTaskTemplateCreateResultDto.new(template: template_dto)

          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:create_masters_crop_task_template_association).with(user, input_dto).returns(result)
          @output_port.expects(:on_success).with(template_dto)

          @interactor.call(input_dto)
        end

        test "should return failure when agricultural_task_id missing" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInputDto.new(
            user_id: 1,
            crop_id: 2,
            agricultural_task_id: nil
          )

          @user_lookup.expects(:find).never
          @gateway.expects(:create_masters_crop_task_template_association).never
          @output_port.expects(:on_failure).with do |failure_dto|
            assert_equal :missing_agricultural_task_id, failure_dto.reason
            true
          end

          @interactor.call(input_dto)
        end

        test "should return failure when agricultural task not found" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInputDto.new(
            user_id: 1,
            crop_id: 2,
            agricultural_task_id: 3
          )
          user = mock
          failure = Domain::Crop::Dtos::MastersCropTaskTemplateCreateFailureDto.new(
            reason: :agricultural_task_not_found
          )
          result = Domain::Crop::Dtos::MastersCropTaskTemplateCreateResultDto.new(failure: failure)

          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:create_masters_crop_task_template_association).with(user, input_dto).returns(result)
          @output_port.expects(:on_failure).with(failure)

          @interactor.call(input_dto)
        end

        test "should return failure when association is forbidden" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInputDto.new(
            user_id: 1,
            crop_id: 2,
            agricultural_task_id: 3
          )
          user = mock
          failure = Domain::Crop::Dtos::MastersCropTaskTemplateCreateFailureDto.new(
            reason: :forbidden
          )
          result = Domain::Crop::Dtos::MastersCropTaskTemplateCreateResultDto.new(failure: failure)

          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:create_masters_crop_task_template_association).with(user, input_dto).returns(result)
          @output_port.expects(:on_failure).with(failure)

          @interactor.call(input_dto)
        end

        test "should return failure when association is duplicate" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInputDto.new(
            user_id: 1,
            crop_id: 2,
            agricultural_task_id: 3
          )
          user = mock
          failure = Domain::Crop::Dtos::MastersCropTaskTemplateCreateFailureDto.new(
            reason: :duplicate
          )
          result = Domain::Crop::Dtos::MastersCropTaskTemplateCreateResultDto.new(failure: failure)

          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:create_masters_crop_task_template_association).with(user, input_dto).returns(result)
          @output_port.expects(:on_failure).with(failure)

          @interactor.call(input_dto)
        end

        test "should return failure when validation fails" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInputDto.new(
            user_id: 1,
            crop_id: 2,
            agricultural_task_id: 3
          )
          user = mock
          record_invalid = Domain::Shared::Exceptions::RecordInvalid.new(
            "invalid",
            errors: [ "Name can't be blank" ]
          )

          @user_lookup.expects(:find).with(1).returns(user)
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
