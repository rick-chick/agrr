# frozen_string_literal: true

module Adapters
  module Crop
    module Mappers
      # ActiveRecord Crop を agrr CLI crop-requirement-file 形式の Hash に変換する。
      class CropAgrrRequirementMapper
        def self.build(crop_model)
          new(crop_model).build
        end

        # ActiveRecord Crop は mapper で組み立て。テスト用スタブは to_agrr_requirement を許容する。
        def self.build_from(crop_model)
          if crop_model.is_a?(::Crop)
            build(crop_model)
          elsif crop_model.respond_to?(:to_agrr_requirement)
            crop_model.to_agrr_requirement
          else
            raise ArgumentError, "Expected Crop record or an object responding to to_agrr_requirement"
          end
        end

        def initialize(crop_model)
          @crop = crop_model
        end

        def build
          sorted_stages = load_sorted_stages

          if sorted_stages.empty?
            raise ArgumentError,
                  "Crop '#{@crop.name}' has no growth stages. Please add growth stages with temperature and thermal requirements."
          end

          stage_requirements = sorted_stages.map { |stage| stage_requirement_hash(stage) }

          {
            "crop" => {
              "crop_id" => @crop.id.to_s,
              "name" => @crop.name,
              "variety" => @crop.variety || "general",
              "area_per_unit" => @crop.area_per_unit || 0.25,
              "revenue_per_area" => @crop.revenue_per_area || 5000.0,
              "max_revenue" => (@crop.revenue_per_area || 5000.0) * 100,
              "groups" => @crop.groups || []
            },
            "stage_requirements" => stage_requirements
          }
        end

        private

        def load_sorted_stages
          assoc = @crop.association(:crop_stages)
          if assoc.loaded?
            @crop.crop_stages.sort_by(&:order)
          else
            @crop.crop_stages.includes(
              :temperature_requirement, :thermal_requirement, :sunshine_requirement, :nutrient_requirement
            ).order(:order).to_a
          end
        end

        def stage_requirement_hash(stage)
          temp_req = stage.temperature_requirement
          thermal_req = stage.thermal_requirement
          sunshine_req = stage.sunshine_requirement
          nutrient_req = stage.nutrient_requirement

          unless temp_req && thermal_req
            raise ArgumentError,
                  "Crop '#{@crop.name}' stage '#{stage.name}' is missing required temperature or thermal requirements."
          end

          stage_hash = {
            "stage" => {
              "name" => stage.name,
              "order" => stage.order
            },
            "temperature" => {
              "base_temperature" => temp_req.base_temperature,
              "optimal_min" => temp_req.optimal_min,
              "optimal_max" => temp_req.optimal_max,
              "low_stress_threshold" => temp_req.low_stress_threshold,
              "high_stress_threshold" => temp_req.high_stress_threshold,
              "frost_threshold" => temp_req.frost_threshold,
              "max_temperature" => temp_req.max_temperature || 50.0
            },
            "thermal" => {
              "required_gdd" => thermal_req.required_gdd
            }
          }

          if sunshine_req
            stage_hash["sunshine"] = {
              "minimum_sunshine_hours" => sunshine_req.minimum_sunshine_hours,
              "target_sunshine_hours" => sunshine_req.target_sunshine_hours
            }
          end

          if nutrient_req
            stage_hash["nutrients"] = {
              "daily_uptake" => {
                "N" => nutrient_req.daily_uptake_n,
                "P" => nutrient_req.daily_uptake_p,
                "K" => nutrient_req.daily_uptake_k
              }
            }
          end

          stage_hash
        end
      end
    end
  end
end
