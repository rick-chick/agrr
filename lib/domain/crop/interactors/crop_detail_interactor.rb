# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropDetailInteractor < Domain::Crop::Ports::CropDetailInputPort
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(crop_id)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(user)
          crop_detail_dto = @gateway.find_crop_show_detail(crop_id)
          Domain::Shared::ReferenceRecordAuthorization.assert_view_allowed!(access_filter, crop_detail_dto.crop)
          html_display = Domain::Shared::Dtos::ResourceDisplayCapabilities.for_crop_detail(user, crop: crop_detail_dto.crop)
          enriched = Domain::Crop::Dtos::CropDetailOutput.new(
            crop: crop_detail_dto.crop,
            task_schedule_blueprints: crop_detail_dto.task_schedule_blueprints,
            available_agricultural_tasks: crop_detail_dto.available_agricultural_tasks,
            selected_task_ids: crop_detail_dto.selected_task_ids,
            associated_pests: crop_detail_dto.associated_pests,
            html_display: html_display
          )
          @output_port.on_success(enriched)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
