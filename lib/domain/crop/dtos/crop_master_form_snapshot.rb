# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      # 作物マスタ HTML フォーム用の読み取りスナップショット（永続モデルをビューに渡さない）。
      # ネスト型は Zeitwerk の慣例に合わせ、ルート定数 CropMasterFormSnapshot の下に置く。
      class CropMasterFormSnapshot
        class TemperatureSnapshot
          attr_reader :id, :base_temperature, :optimal_min, :optimal_max, :low_stress_threshold,
                      :high_stress_threshold, :frost_threshold, :sterility_risk_threshold, :max_temperature, :_destroy

          def initialize(id: nil, base_temperature: nil, optimal_min: nil, optimal_max: nil,
                         low_stress_threshold: nil, high_stress_threshold: nil, frost_threshold: nil,
                         sterility_risk_threshold: nil, max_temperature: nil, _destroy: false)
            @id = id
            @base_temperature = base_temperature
            @optimal_min = optimal_min
            @optimal_max = optimal_max
            @low_stress_threshold = low_stress_threshold
            @high_stress_threshold = high_stress_threshold
            @frost_threshold = frost_threshold
            @sterility_risk_threshold = sterility_risk_threshold
            @max_temperature = max_temperature
            @_destroy = _destroy
          end

          def _destroy
            @_destroy
          end
        end

        class ThermalSnapshot
          attr_reader :id, :required_gdd, :_destroy

          def initialize(id: nil, required_gdd: nil, _destroy: false)
            @id = id
            @required_gdd = required_gdd
            @_destroy = _destroy
          end

          def _destroy
            @_destroy
          end
        end

        class SunshineSnapshot
          attr_reader :id, :minimum_sunshine_hours, :target_sunshine_hours, :_destroy

          def initialize(id: nil, minimum_sunshine_hours: nil, target_sunshine_hours: nil, _destroy: false)
            @id = id
            @minimum_sunshine_hours = minimum_sunshine_hours
            @target_sunshine_hours = target_sunshine_hours
            @_destroy = _destroy
          end

          def _destroy
            @_destroy
          end
        end

        class NutrientSnapshot
          attr_reader :id, :daily_uptake_n, :daily_uptake_p, :daily_uptake_k, :region, :_destroy

          def initialize(id: nil, daily_uptake_n: nil, daily_uptake_p: nil, daily_uptake_k: nil, region: nil, _destroy: false)
            @id = id
            @daily_uptake_n = daily_uptake_n
            @daily_uptake_p = daily_uptake_p
            @daily_uptake_k = daily_uptake_k
            @region = region
            @_destroy = _destroy
          end

          def _destroy
            @_destroy
          end
        end

        class StageSnapshot
          attr_reader :id, :crop_id, :name, :order, :_destroy, :temperature_requirement, :thermal_requirement,
                      :sunshine_requirement, :nutrient_requirement

          def initialize(id:, crop_id:, name:, order:, _destroy:, temperature_requirement:, thermal_requirement:,
                         sunshine_requirement:, nutrient_requirement:)
            @id = id
            @crop_id = crop_id
            @name = name
            @order = order
            @_destroy = _destroy
            @temperature_requirement = temperature_requirement
            @thermal_requirement = thermal_requirement
            @sunshine_requirement = sunshine_requirement
            @nutrient_requirement = nutrient_requirement
          end

          def _destroy
            @_destroy
          end
        end

        attr_reader :id, :user_id, :name, :variety, :region, :groups, :area_per_unit, :revenue_per_area, :is_reference,
                    :crop_stages, :error_messages

        def initialize(id:, user_id:, name:, variety:, region:, groups:, area_per_unit:, revenue_per_area:, is_reference:,
                       crop_stages:, new_record:, error_messages: [])
          @id = id
          @user_id = user_id
          @name = name
          @variety = variety
          @region = region
          @groups = groups || []
          @area_per_unit = area_per_unit
          @revenue_per_area = revenue_per_area
          @is_reference = is_reference
          @crop_stages = crop_stages || []
          @new_record = new_record
          @error_messages = Array(error_messages)
        end

        def new_record?
          @new_record
        end

        def persisted?
          !@new_record && Domain::Shared.present?(@id)
        end

        def self.for_unsaved_blank_form
          new(
            id: nil,
            user_id: nil,
            name: nil,
            variety: nil,
            region: nil,
            groups: [],
            area_per_unit: nil,
            revenue_per_area: nil,
            is_reference: false,
            crop_stages: [],
            new_record: true,
            error_messages: []
          )
        end
      end
    end
  end
end
