# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class CropsNestedPestsUpdateInteractor
        def initialize(output_port:, pest_gateway:)
          @output_port = output_port
          @pest_gateway = pest_gateway
        end

        def call(crop_id:, pest_id:, pest_attrs:, admin:)
          result = @pest_gateway.update_pest_for_crop(
            crop_id: crop_id,
            pest_id: pest_id,
            pest_attrs: pest_attrs,
            admin: admin
          )

          case result[:status]
          when :reference_flag_denied
            @output_port.on_reference_flag_denied(crop_id: crop_id, pest: result[:pest_record])
          when :updated
            @output_port.on_updated(crop_id: crop_id, pest: result[:pest_record])
          when :invalid
            @output_port.on_invalid(crop_id: crop_id, pest: result[:pest_record])
          end
        end
      end
    end
  end
end
