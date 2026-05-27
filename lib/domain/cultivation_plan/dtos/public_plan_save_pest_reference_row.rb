# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 公開プラン保存: 参照害虫 1 行（子プロファイルはネスト DTO）。
      class PublicPlanSavePestReferenceRow
        attr_reader :reference_pest_id, :name, :name_scientific, :family, :order,
                    :description, :occurrence_season, :region,
                    :linked_reference_crop_ids, :temperature_profile, :thermal_requirement,
                    :control_methods

        def initialize(
          reference_pest_id:,
          name:,
          name_scientific: nil,
          family: nil,
          order: nil,
          description: nil,
          occurrence_season: nil,
          region: nil,
          linked_reference_crop_ids: [],
          temperature_profile: nil,
          thermal_requirement: nil,
          control_methods: []
        )
          @reference_pest_id = reference_pest_id.to_i
          @name = name.nil? ? nil : name.to_s
          @name_scientific = name_scientific
          @family = family
          @order = order
          @description = description
          @occurrence_season = occurrence_season
          @region = region
          @linked_reference_crop_ids = Array(linked_reference_crop_ids).map(&:to_i).freeze
          @temperature_profile = temperature_profile
          @thermal_requirement = thermal_requirement
          @control_methods = Array(control_methods).freeze
          freeze
        end
      end
    end
  end
end
