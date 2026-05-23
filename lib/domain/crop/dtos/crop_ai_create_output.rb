# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropAiCreateOutput
        attr_reader :http_status, :success, :crop_id, :crop_name, :variety, :area_per_unit,
                    :revenue_per_area, :stages_count, :is_reference, :message

        def initialize(
          http_status:,
          crop_id:,
          crop_name:,
          variety:,
          area_per_unit:,
          revenue_per_area:,
          stages_count:,
          message:,
          is_reference: nil
        )
          @http_status = http_status
          @success = true
          @crop_id = crop_id
          @crop_name = crop_name
          @variety = variety
          @area_per_unit = area_per_unit
          @revenue_per_area = revenue_per_area
          @stages_count = stages_count
          @is_reference = is_reference
          @message = message
        end
      end
    end
  end
end
