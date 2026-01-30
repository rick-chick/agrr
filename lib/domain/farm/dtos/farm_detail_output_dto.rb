# frozen_string_literal: true

module Domain
  module Farm
    module Dtos
      class FarmDetailOutputDto
        attr_reader :farm, :fields

        def initialize(farm:, fields:)
          @farm = farm
          @fields = fields
        end

        def self.from_models(farm_model, field_models)
          farm_entity = Domain::Farm::Entities::FarmEntity.from_model(farm_model)
          field_entities = field_models.map do |field_model|
            Domain::Farm::Entities::FieldEntity.from_model(field_model)
          end

          new(farm: farm_entity, fields: field_entities)
        end
      end
    end
  end
end