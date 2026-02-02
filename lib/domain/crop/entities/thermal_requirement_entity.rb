# frozen_string_literal: true

module Domain
  module Crop
    module Entities
      class ThermalRequirementEntity
        attr_reader :id, :crop_stage_id, :required_gdd

        def initialize(attributes)
          @id = attributes[:id]
          @crop_stage_id = attributes[:crop_stage_id]
          @required_gdd = attributes[:required_gdd]

          validate!
        end

        # ActiveRecordモデルからの変換
        def self.from_model(model)
          new(
            id: model.id,
            crop_stage_id: model.crop_stage_id,
            required_gdd: model.required_gdd
          )
        end

        private

        def validate!
          raise ArgumentError, "Crop stage ID is required" if crop_stage_id.blank?
        end
      end
    end
  end
end