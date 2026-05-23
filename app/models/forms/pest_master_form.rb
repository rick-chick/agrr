# frozen_string_literal: true

module Forms
  class PestMasterForm
    include Forms::HtmlFormSupport

    attr_accessor :name, :name_scientific, :family, :order, :description, :occurrence_season, :is_reference, :region, :user_id
    attr_reader :id, :created_at, :updated_at

    def self.model_name
      Domain::Shared::FormModelName.from_logical_name("Pest")
    end

    def self.from_edit_payload(payload)
      obj = new
      obj.instance_variable_set(:@id, payload.id)
      obj.instance_variable_set(:@_new_record, payload.new_record?)
      obj.instance_variable_set(:@created_at, payload.created_at)
      obj.instance_variable_set(:@updated_at, payload.updated_at)
      obj.name = payload.name
      obj.name_scientific = payload.name_scientific
      obj.family = payload.family
      obj.order = payload.order
      obj.description = payload.description
      obj.occurrence_season = payload.occurrence_season
      obj.is_reference = payload.is_reference
      obj.region = payload.region
      obj.user_id = payload.user_id
      obj.instance_variable_set(
        :@pest_temperature_profile,
        PestTemperatureProfileMasterForm.from_attrs(payload.pest_temperature_profile_attributes)
      )
      obj.instance_variable_set(
        :@pest_thermal_requirement,
        PestThermalRequirementMasterForm.from_attrs(payload.pest_thermal_requirement_attributes)
      )
      cm =
        (payload.pest_control_methods_attributes || {}).sort_by { |k, _| k.to_s.to_i }.map do |_, v|
          PestControlMethodMasterForm.from_attrs(v)
        end
      cm = [ PestControlMethodMasterForm.from_attrs({}) ] if cm.empty?
      obj.instance_variable_set(:@pest_control_methods, cm)
      payload.error_messages.each { |msg| obj.errors.add(:base, msg) }
      obj
    end

    def pest_control_methods
      @pest_control_methods ||= []
    end

    def id=(v)
      @id = v
    end

    def persisted?
      !new_record?
    end

    def new_record?
      return @_new_record if defined?(@_new_record)

      @id.blank?
    end

    def pest_temperature_profile
      @pest_temperature_profile ||= PestTemperatureProfileMasterForm.from_attrs({})
    end

    def pest_thermal_requirement
      @pest_thermal_requirement ||= PestThermalRequirementMasterForm.from_attrs({})
    end

    def is_reference?
      Domain::Shared::TypeConverters::BooleanConverter.cast(is_reference)
    end

    def to_param
      id.present? ? id.to_s : ""
    end

    def pest_temperature_profile_attributes=(_attrs); end

    def pest_thermal_requirement_attributes=(_attrs); end

    def pest_control_methods_attributes=(_attrs); end
  end
end
