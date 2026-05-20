# frozen_string_literal: true

module Forms
  class PestTemperatureProfileMasterForm
    include Forms::HtmlFormSupport

    attr_accessor :id, :base_temperature, :max_temperature, :_destroy

    def self.model_name
      Domain::Shared::FormModelName.from_logical_name("PestTemperatureProfile")
    end

    def self.from_attrs(attrs)
      obj = new
      return obj if attrs.blank?

      h = attrs.symbolize_keys
      obj.id = h[:id].presence
      obj.base_temperature = h[:base_temperature]
      obj.max_temperature = h[:max_temperature]
      obj._destroy = Domain::Shared::TypeConverters::BooleanConverter.cast(h[:_destroy])
      obj
    end

    def persisted?
      id.present?
    end

    def new_record?
      id.blank?
    end

    def to_nested_attributes
      h = {
        base_temperature: base_temperature,
        max_temperature: max_temperature
      }
      h[:id] = id if id.present?
      h[:_destroy] = true if Domain::Shared::TypeConverters::BooleanConverter.cast(_destroy)
      h
    end
  end
end
