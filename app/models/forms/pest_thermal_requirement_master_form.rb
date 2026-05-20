# frozen_string_literal: true

module Forms
  class PestThermalRequirementMasterForm
    include Forms::HtmlFormSupport

    attr_accessor :id, :required_gdd, :first_generation_gdd, :_destroy

    def self.model_name
      Domain::Shared::FormModelName.from_logical_name("PestThermalRequirement")
    end

    def self.from_attrs(attrs)
      obj = new
      return obj if attrs.blank?

      h = attrs.symbolize_keys
      obj.id = h[:id].presence
      obj.required_gdd = h[:required_gdd]
      obj.first_generation_gdd = h[:first_generation_gdd]
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
        required_gdd: required_gdd,
        first_generation_gdd: first_generation_gdd
      }
      h[:id] = id if id.present?
      h[:_destroy] = true if Domain::Shared::TypeConverters::BooleanConverter.cast(_destroy)
      h
    end
  end
end
