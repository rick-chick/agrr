# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class CropsNestedPestsLoadPestInteractor
        def initialize(output_port:, pest_gateway:)
          @output_port = output_port
          @pest_gateway = pest_gateway
        end

        def call(crop_id:, pest_id:, for_edit_form: false)
          result = @pest_gateway.find_pest_in_crop(crop_id: crop_id, pest_id: pest_id)
          if result[:status] == :found
            @pest_gateway.prepare_crop_nested_pest_for_edit_form!(result[:pest_record]) if for_edit_form
            @output_port.on_success(result[:pest_record])
          else
            @output_port.on_not_found(crop_id: crop_id)
          end
        end
      end
    end
  end
end
