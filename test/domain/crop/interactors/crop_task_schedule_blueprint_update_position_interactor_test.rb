# frozen_string_literal: true

require "test_helper"

module Domain
  module Crop
    module Interactors
      class CropTaskScheduleBlueprintUpdatePositionInteractorTest < ActiveSupport::TestCase
        setup do
          @user = create(:user)
          @gateway = Object.new
          @user_lookup = Object.new
          @output = mock("output_port")
          @interactor = Domain::Crop::Interactors::CropTaskScheduleBlueprintUpdatePositionInteractor.new(
            output_port: @output,
            gateway: @gateway,
            user_lookup: @user_lookup
          )
        end

        test "call returns bad_request when gdd_trigger is negative" do
          dto = Domain::Crop::Dtos::CropTaskScheduleBlueprintUpdatePositionInputDto.new(
            user_id: @user.id,
            crop_id: 1,
            blueprint_id: 2,
            gdd_trigger: -1.0,
            priority: nil
          )

          @output.expects(:on_bad_request).with("gdd_trigger must be non-negative")

          @interactor.call(dto)
        end

        test "call forwards PolicyPermissionDenied to on_forbidden" do
          dto = Domain::Crop::Dtos::CropTaskScheduleBlueprintUpdatePositionInputDto.new(
            user_id: @user.id,
            crop_id: 1,
            blueprint_id: 2,
            gdd_trigger: 1.0,
            priority: nil
          )

          @user_lookup.expects(:find).with(@user.id).returns(@user)
          @gateway.expects(:update_task_schedule_blueprint_position_for_user).raises(Domain::Shared::Policies::PolicyPermissionDenied)
          @output.expects(:on_forbidden)

          @interactor.call(dto)
        end
      end
    end
  end
end
