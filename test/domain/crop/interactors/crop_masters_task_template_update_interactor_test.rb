# frozen_string_literal: true

require "test_helper"

module Domain
  module Crop
    module Interactors
      class CropMastersTaskTemplateUpdateInteractorTest < ActiveSupport::TestCase
        setup do
          @gateway = mock
          @output_port = mock
          @user_lookup = mock
          @interactor = CropMastersTaskTemplateUpdateInteractor.new(
            output_port: @output_port,
            gateway: @gateway,
            user_lookup: @user_lookup
          )
        end

        test "should return updated row successfully" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateUpdateInputDto.new(
            user_id: 1,
            crop_id: 2,
            template_id: 3,
            attributes: { "name" => "x" }
          )
          user = mock
          row = { "id" => 3, "name" => "x" }

          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:update_masters_crop_task_template_for_api).with(
            user: user,
            crop_id: 2,
            template_id: 3,
            attributes: { "name" => "x" }
          ).returns({ ok: true, row: row })
          @output_port.expects(:on_success).with(row)

          @interactor.call(input_dto)
        end

        test "should return validation_failed when gateway returns ok false" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateUpdateInputDto.new(
            user_id: 1,
            crop_id: 2,
            template_id: 3,
            attributes: {}
          )
          user = mock

          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:update_masters_crop_task_template_for_api).returns(
            { ok: false, errors: [ "Name can't be blank" ] }
          )
          @output_port.expects(:on_failure).with do |failure_dto|
            assert_equal :validation_failed, failure_dto.reason
            assert_equal [ "Name can't be blank" ], failure_dto.errors
            true
          end

          @interactor.call(input_dto)
        end

        test "should return association_not_found when gateway raises RecordNotFound" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateUpdateInputDto.new(
            user_id: 1,
            crop_id: 2,
            template_id: 3,
            attributes: {}
          )
          user = mock

          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:update_masters_crop_task_template_for_api).raises(
            Domain::Shared::Exceptions::RecordNotFound
          )
          @output_port.expects(:on_failure).with do |failure_dto|
            assert_equal :association_not_found, failure_dto.reason
            true
          end

          @interactor.call(input_dto)
        end
      end
    end
  end
end
