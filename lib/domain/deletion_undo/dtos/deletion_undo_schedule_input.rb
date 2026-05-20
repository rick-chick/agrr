# frozen_string_literal: true

module Domain
  module DeletionUndo
    module Dtos
      # 永続化対象は type + id のみ（Interactor / DTO に AR を載せない）。
      class DeletionUndoScheduleInput
        attr_reader :resource_type, :resource_id, :actor_id, :toast_message, :auto_hide_after, :metadata,
                    :validate_before_schedule

        def initialize(resource_type:, resource_id:, actor_id: nil, toast_message: nil, auto_hide_after: nil,
                       metadata: {}, validate_before_schedule: false)
          @resource_type = resource_type
          @resource_id = resource_id
          @actor_id = actor_id
          @toast_message = toast_message
          @auto_hide_after = auto_hide_after
          @metadata = metadata
          @validate_before_schedule = validate_before_schedule
        end
      end
    end
  end
end
