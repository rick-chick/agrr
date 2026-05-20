# frozen_string_literal: true

module Forms
  class CropTemperatureRequirementMasterForm
    include Forms::HtmlFormSupport

    attr_accessor :base_temperature, :optimal_min, :optimal_max, :low_stress_threshold,
                  :high_stress_threshold, :frost_threshold, :sterility_risk_threshold, :max_temperature, :_destroy
    attr_reader :id

    def self.model_name
      Domain::Shared::FormModelName.from_logical_name("TemperatureRequirement")
    end

    def self.from_snapshot(snap)
      o = new
      o.instance_variable_set(:@id, snap.id)
      o.base_temperature = snap.base_temperature
      o.optimal_min = snap.optimal_min
      o.optimal_max = snap.optimal_max
      o.low_stress_threshold = snap.low_stress_threshold
      o.high_stress_threshold = snap.high_stress_threshold
      o.frost_threshold = snap.frost_threshold
      o.sterility_risk_threshold = snap.sterility_risk_threshold
      o.max_temperature = snap.max_temperature
      o._destroy = snap._destroy
      o
    end

    def id=(v)
      @id = v
    end

    def to_nested_attributes
      h = {
        base_temperature: base_temperature,
        optimal_min: optimal_min,
        optimal_max: optimal_max,
        low_stress_threshold: low_stress_threshold,
        high_stress_threshold: high_stress_threshold,
        frost_threshold: frost_threshold,
        sterility_risk_threshold: sterility_risk_threshold,
        max_temperature: max_temperature
      }
      h[:id] = id if id.present?
      h[:_destroy] = Domain::Shared::TypeConverters::BooleanConverter.cast(_destroy)
      h
    end
  end
end
