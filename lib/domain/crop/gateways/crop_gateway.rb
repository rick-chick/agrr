# frozen_string_literal: true

module Domain
  module Crop
    module Gateways
      class CropGateway
        def list
          raise NotImplementedError, "Subclasses must implement list"
        end

        def find_by_id(crop_id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        def create(create_input_dto)
          raise NotImplementedError, "Subclasses must implement create"
        end

        def update(crop_id, update_input_dto)
          raise NotImplementedError, "Subclasses must implement update"
        end

        # CropStage methods
        def create_crop_stage(crop_stage_dto)
          raise NotImplementedError, "Subclasses must implement create_crop_stage"
        end

        def update_crop_stage(crop_stage_id, crop_stage_dto)
          raise NotImplementedError, "Subclasses must implement update_crop_stage"
        end

        def delete_crop_stage(crop_stage_id)
          raise NotImplementedError, "Subclasses must implement delete_crop_stage"
        end

        # TemperatureRequirement methods
        def find_temperature_requirement(crop_stage_id)
          raise NotImplementedError, "Subclasses must implement find_temperature_requirement"
        end

        def create_temperature_requirement(crop_stage_id, requirement_dto)
          raise NotImplementedError, "Subclasses must implement create_temperature_requirement"
        end

        def update_temperature_requirement(crop_stage_id, requirement_dto)
          raise NotImplementedError, "Subclasses must implement update_temperature_requirement"
        end

        # ThermalRequirement methods
        def find_thermal_requirement(crop_stage_id)
          raise NotImplementedError, "Subclasses must implement find_thermal_requirement"
        end

        def create_thermal_requirement(crop_stage_id, requirement_dto)
          raise NotImplementedError, "Subclasses must implement create_thermal_requirement"
        end

        def update_thermal_requirement(crop_stage_id, requirement_dto)
          raise NotImplementedError, "Subclasses must implement update_thermal_requirement"
        end

        # SunshineRequirement methods
        def find_sunshine_requirement(crop_stage_id)
          raise NotImplementedError, "Subclasses must implement find_sunshine_requirement"
        end

        def create_sunshine_requirement(crop_stage_id, requirement_dto)
          raise NotImplementedError, "Subclasses must implement create_sunshine_requirement"
        end

        def update_sunshine_requirement(crop_stage_id, requirement_dto)
          raise NotImplementedError, "Subclasses must implement update_sunshine_requirement"
        end

        # NutrientRequirement methods
        def find_nutrient_requirement(crop_stage_id)
          raise NotImplementedError, "Subclasses must implement find_nutrient_requirement"
        end

        def create_nutrient_requirement(crop_stage_id, requirement_dto)
          raise NotImplementedError, "Subclasses must implement create_nutrient_requirement"
        end

        def update_nutrient_requirement(crop_stage_id, requirement_dto)
          raise NotImplementedError, "Subclasses must implement update_nutrient_requirement"
        end

      end
    end
  end
end


