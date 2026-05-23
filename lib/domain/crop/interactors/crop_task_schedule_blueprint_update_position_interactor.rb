# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropTaskScheduleBlueprintUpdatePositionInteractor
        def initialize(output_port:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_lookup = user_lookup
        end

        def call(input_dto)
          if input_dto.gdd_trigger.is_a?(Numeric) && input_dto.gdd_trigger.negative?
            return @output_port.on_bad_request("gdd_trigger must be non-negative")
          end

          if input_dto.priority.is_a?(Numeric) && input_dto.priority.negative?
            return @output_port.on_bad_request("priority must be non-negative")
          end

          user = @user_lookup.find(input_dto.user_id)
          access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(user)
          crop_entity = @gateway.find_by_id(input_dto.crop_id)
          Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(access_filter, crop_entity)
          out = @gateway.update_task_schedule_blueprint_position_for_user(
            user: user,
            crop_id: input_dto.crop_id,
            blueprint_id: input_dto.blueprint_id,
            gdd_trigger: input_dto.gdd_trigger,
            priority: input_dto.priority,
          )

          if out[:ok]
            @output_port.on_success(out[:payload])
          elsif out[:status] == :not_found
            @output_port.on_not_found(out[:error])
          else
            @output_port.on_mutation_failure(out[:status], out[:error])
          end
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_forbidden
        end
      end
    end
  end
end
