# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropTaskScheduleBlueprintDestroyInteractor
        def initialize(output_port:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_lookup = user_lookup
        end

        def call(input_dto)
          user = @user_lookup.find(input_dto.user_id)
          access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(user)
          result = @gateway.delete_task_schedule_blueprint_bundle_in_crop!(
            user,
            input_dto.crop_id,
            input_dto.blueprint_id,
            access_filter: access_filter
          )

          if result[:not_found]
            return @output_port.on_not_found(blueprint_id: input_dto.blueprint_id)
          end

          blueprint_id_for_response = result[:blueprint_id_for_response]
          crop = result[:crop]
          reload = @gateway.reload_crop_after_task_schedule_blueprint_delete!(
            crop: crop,
            blueprint_id_for_response: blueprint_id_for_response
          )

          unless reload[:ok]
            return @output_port.on_reload_failed(blueprint_id: input_dto.blueprint_id)
          end

          @output_port.on_success(
            blueprint_id: blueprint_id_for_response,
            crop: reload[:crop],
            available_agricultural_tasks: reload[:available_agricultural_tasks],
            selected_task_ids: reload[:selected_task_ids]
          )
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_forbidden
        end
      end
    end
  end
end
