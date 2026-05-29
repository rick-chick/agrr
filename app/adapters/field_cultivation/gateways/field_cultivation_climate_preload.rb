# frozen_string_literal: true

module Adapters
  module FieldCultivation
    module Gateways
      # Field cultivation read for climate / API summary（auth は Interactor + Policy）。
      module FieldCultivationClimatePreload
        INCLUDES = [
          { cultivation_plan: { farm: :weather_location } },
          :cultivation_plan_crop
        ].freeze

        module_function

        # @param field_cultivation_id [Integer, String]
        # @return [::FieldCultivation]
        # @raise [ActiveRecord::RecordNotFound]
        def find!(field_cultivation_id:)
          ::FieldCultivation.includes(INCLUDES).find(field_cultivation_id)
        end
      end
    end
  end
end
