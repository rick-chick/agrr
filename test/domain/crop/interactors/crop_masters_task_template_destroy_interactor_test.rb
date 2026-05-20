# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropMastersTaskTemplateDestroyInteractorTest < DomainLibTestCase
        setup do
          @gateway = mock
          @output_port = mock
          @user_lookup = mock
          @interactor = CropMastersTaskTemplateDestroyInteractor.new(
            output_port: @output_port,
            gateway: @gateway,
            user_lookup: @user_lookup
          )
        end

        test "should succeed when gateway destroys" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateDestroyInput.new(
            user_id: 1,
            crop_id: 2,
            template_id: 3
          )
          user = mock

          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:destroy_masters_crop_task_template_for_api!).with(
            user: user,
            crop_id: 2,
            template_id: 3,
            access_filter: anything
          ).returns(:ok)
          @output_port.expects(:on_success)

          @interactor.call(input_dto)
        end

        test "should return association_not_found when gateway raises RecordNotFound" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateDestroyInput.new(
            user_id: 1,
            crop_id: 2,
            template_id: 3
          )
          user = mock

          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:destroy_masters_crop_task_template_for_api!).with(
            user: user,
            crop_id: 2,
            template_id: 3,
            access_filter: anything
          ).raises(
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
