# frozen_string_literal: true

module Domain
  module Crop
    module Entities
      class SunshineRequirementEntity
        attr_reader :id, :crop_stage_id, :minimum_sunshine_hours, :target_sunshine_hours

        def initialize(attributes)
          @id = attributes[:id]
          @crop_stage_id = attributes[:crop_stage_id]
          @minimum_sunshine_hours = attributes[:minimum_sunshine_hours]
          @target_sunshine_hours = attributes[:target_sunshine_hours]

          validate!
        end

        # ActiveRecordモデルからの変換
        def self.from_model(model)
          new(
            id: model.id,
            crop_stage_id: model.crop_stage_id,
            minimum_sunshine_hours: model.minimum_sunshine_hours,
            target_sunshine_hours: model.target_sunshine_hours
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