# frozen_string_literal: true

module Forms
  class CropThermalRequirementMasterForm
    include Forms::HtmlFormSupport

    attr_accessor :required_gdd, :_destroy
    attr_reader :id

    def self.model_name
      Domain::Shared::FormModelName.from_logical_name("ThermalRequirement")
    end

    def self.from_snapshot(snap)
      o = new
      o.instance_variable_set(:@id, snap.id)
      o.required_gdd = snap.required_gdd
      o._destroy = snap._destroy
      o
    end

    def id=(v)
      @id = v
    end

    def to_nested_attributes
      h = { required_gdd: required_gdd }
      h[:id] = id if id.present?
      h[:_destroy] = Domain::Shared::TypeConverters::BooleanConverter.cast(_destroy)
      h
    end
  end
end
