# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PublicPlanSavePesticideReferenceRow
        attr_reader :reference_pesticide_id, :reference_crop_id, :reference_pest_id,
                    :name, :active_ingredient, :description, :region,
                    :usage_constraint, :application_detail

        def initialize(
          reference_pesticide_id:,
          reference_crop_id:,
          reference_pest_id:,
          name:,
          active_ingredient: nil,
          description: nil,
          region: nil,
          usage_constraint: nil,
          application_detail: nil
        )
          @reference_pesticide_id = reference_pesticide_id.to_i
          @reference_crop_id = reference_crop_id.to_i
          @reference_pest_id = reference_pest_id.to_i
          @name = name.nil? ? nil : name.to_s
          @active_ingredient = active_ingredient
          @description = description
          @region = region
          @usage_constraint = usage_constraint
          @application_detail = application_detail
          freeze
        end
      end
    end
  end
end
