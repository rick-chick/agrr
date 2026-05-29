# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropShowDetailTemperatureRequirementSnapshot
        attr_reader :id, :crop_stage_id, :base_temperature, :optimal_min, :optimal_max,
                    :low_stress_threshold, :high_stress_threshold, :frost_threshold,
                    :sterility_risk_threshold, :max_temperature

        def initialize(id:, crop_stage_id:, base_temperature:, optimal_min:, optimal_max:,
                       low_stress_threshold:, high_stress_threshold:, frost_threshold:,
                       sterility_risk_threshold:, max_temperature:)
          @id = id
          @crop_stage_id = crop_stage_id
          @base_temperature = base_temperature
          @optimal_min = optimal_min
          @optimal_max = optimal_max
          @low_stress_threshold = low_stress_threshold
          @high_stress_threshold = high_stress_threshold
          @frost_threshold = frost_threshold
          @sterility_risk_threshold = sterility_risk_threshold
          @max_temperature = max_temperature
          freeze
        end
      end

      class CropShowDetailThermalRequirementSnapshot
        attr_reader :id, :crop_stage_id, :required_gdd

        def initialize(id:, crop_stage_id:, required_gdd:)
          @id = id
          @crop_stage_id = crop_stage_id
          @required_gdd = required_gdd
          freeze
        end
      end

      class CropShowDetailSunshineRequirementSnapshot
        attr_reader :id, :crop_stage_id, :minimum_sunshine_hours, :target_sunshine_hours

        def initialize(id:, crop_stage_id:, minimum_sunshine_hours:, target_sunshine_hours:)
          @id = id
          @crop_stage_id = crop_stage_id
          @minimum_sunshine_hours = minimum_sunshine_hours
          @target_sunshine_hours = target_sunshine_hours
          freeze
        end
      end

      class CropShowDetailNutrientRequirementSnapshot
        attr_reader :id, :crop_stage_id, :daily_uptake_n, :daily_uptake_p, :daily_uptake_k, :region

        def initialize(id:, crop_stage_id:, daily_uptake_n:, daily_uptake_p:, daily_uptake_k:, region:)
          @id = id
          @crop_stage_id = crop_stage_id
          @daily_uptake_n = daily_uptake_n
          @daily_uptake_p = daily_uptake_p
          @daily_uptake_k = daily_uptake_k
          @region = region
          freeze
        end
      end

      class CropShowDetailStageSnapshot
        attr_reader :id, :crop_id, :name, :order, :created_at, :updated_at,
                    :temperature_requirement, :thermal_requirement,
                    :sunshine_requirement, :nutrient_requirement

        def initialize(id:, crop_id:, name:, order:, created_at:, updated_at:,
                       temperature_requirement:, thermal_requirement:,
                       sunshine_requirement:, nutrient_requirement:)
          @id = id
          @crop_id = crop_id
          @name = name
          @order = order
          @created_at = created_at
          @updated_at = updated_at
          @temperature_requirement = temperature_requirement
          @thermal_requirement = thermal_requirement
          @sunshine_requirement = sunshine_requirement
          @nutrient_requirement = nutrient_requirement
          freeze
        end
      end

      class CropShowDetailPestSnapshot
        attr_reader :id, :user_id, :name, :name_scientific, :family, :order,
                    :description, :occurrence_season, :region, :is_reference,
                    :created_at, :updated_at

        def initialize(id:, user_id:, name:, name_scientific:, family:, order:,
                       description:, occurrence_season:, region:, is_reference:,
                       created_at:, updated_at:)
          @id = id
          @user_id = user_id
          @name = name
          @name_scientific = name_scientific
          @family = family
          @order = order
          @description = description
          @occurrence_season = occurrence_season
          @region = region
          @is_reference = is_reference
          @created_at = created_at
          @updated_at = updated_at
          freeze
        end
      end

      class CropShowDetailSnapshot
        attr_reader :id, :user_id, :name, :variety, :is_reference, :area_per_unit,
                    :revenue_per_area, :region, :groups, :created_at, :updated_at,
                    :crop_stages, :pests

        def initialize(id:, user_id:, name:, variety:, is_reference:, area_per_unit:,
                       revenue_per_area:, region:, groups:, created_at:, updated_at:,
                       crop_stages:, pests:)
          @id = id
          @user_id = user_id
          @name = name
          @variety = variety
          @is_reference = is_reference
          @area_per_unit = area_per_unit
          @revenue_per_area = revenue_per_area
          @region = region
          @groups = groups
          @created_at = created_at
          @updated_at = updated_at
          @crop_stages = crop_stages
          @pests = pests
          freeze
        end
      end
    end
  end
end
