# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # REST add_crop 協調処理の結果。
      class RestAddCropCoordinatorOutput
        attr_reader :kind, :plan_crop_id, :plan_crop_display_name, :technical_details, :adjust_payload, :message

        def initialize(kind:, plan_crop_id: nil, plan_crop_display_name: nil, technical_details: nil,
                       adjust_payload: nil, message: nil)
          @kind = kind
          @plan_crop_id = plan_crop_id
          @plan_crop_display_name = plan_crop_display_name
          @technical_details = technical_details
          @adjust_payload = adjust_payload
          @message = message
        end
      end
    end
  end
end
