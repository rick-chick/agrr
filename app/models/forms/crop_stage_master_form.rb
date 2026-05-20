# frozen_string_literal: true

module Forms
  class CropStageMasterForm
    include Forms::HtmlFormSupport

    attr_accessor :name, :order, :_destroy
    attr_reader :id, :crop_id, :temperature_requirement, :thermal_requirement, :sunshine_requirement, :nutrient_requirement

    def self.model_name
      Domain::Shared::FormModelName.from_logical_name("CropStage")
    end

    def self.from_snapshot(snap)
      o = new
      o.instance_variable_set(:@id, snap.id)
      o.instance_variable_set(:@crop_id, snap.crop_id)
      o.name = snap.name
      o.order = snap.order
      o._destroy = snap._destroy
      o.instance_variable_set(:@temperature_requirement, CropTemperatureRequirementMasterForm.from_snapshot(snap.temperature_requirement))
      o.instance_variable_set(:@thermal_requirement, CropThermalRequirementMasterForm.from_snapshot(snap.thermal_requirement))
      o.instance_variable_set(:@sunshine_requirement, CropSunshineRequirementMasterForm.from_snapshot(snap.sunshine_requirement))
      o.instance_variable_set(:@nutrient_requirement, CropNutrientRequirementMasterForm.from_snapshot(snap.nutrient_requirement))
      o
    end

    def id=(v)
      @id = v
    end

    def crop_id=(v)
      @crop_id = v
    end

    def marked_for_destruction?
      Domain::Shared::TypeConverters::BooleanConverter.cast(_destroy)
    end

    def persisted?
      id.present?
    end

    def new_record?
      !persisted?
    end

    def to_nested_attributes
      h = {
        name: name,
        order: order,
        temperature_requirement_attributes: temperature_requirement.to_nested_attributes,
        thermal_requirement_attributes: thermal_requirement.to_nested_attributes,
        sunshine_requirement_attributes: sunshine_requirement.to_nested_attributes,
        nutrient_requirement_attributes: nutrient_requirement.to_nested_attributes
      }
      h[:id] = id if id.present?
      h[:_destroy] = true if marked_for_destruction?
      h
    end
  end
end
