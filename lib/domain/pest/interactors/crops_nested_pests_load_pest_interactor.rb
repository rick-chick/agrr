# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class CropsNestedPestsLoadPestInteractor
        def initialize(output_port:, pest_gateway:)
          @output_port = output_port
          @pest_gateway = pest_gateway
        end

        def call(crop, pest_id)
          crop_id = crop.respond_to?(:id) ? crop.id : crop
          result = @pest_gateway.find_pest_in_crop(crop_id: crop_id, pest_id: pest_id)
          if result[:status] == :found
            @output_port.on_success(result[:pest_record])
          else
            @output_port.on_not_found(crop)
          end
        end
      end
    end
  end
end
