# frozen_string_literal: true

module Forms
  class PestMasterForm
    include Forms::HtmlFormSupport

    attr_accessor :name, :name_scientific, :family, :order, :description, :occurrence_season, :is_reference, :region, :user_id
    attr_reader :id, :associated_crop_ids, :created_at, :updated_at

    def self.model_name
      Domain::Shared::FormModelName.from_logical_name("Pest")
    end

    def self.from_snapshot(snapshot)
      obj = new
      obj.instance_variable_set(:@id, snapshot.id)
      obj.instance_variable_set(:@_new_record, snapshot.new_record?)
      obj.instance_variable_set(:@created_at, snapshot.created_at)
      obj.instance_variable_set(:@updated_at, snapshot.updated_at)
      obj.name = snapshot.name
      obj.name_scientific = snapshot.name_scientific
      obj.family = snapshot.family
      obj.order = snapshot.order
      obj.description = snapshot.description
      obj.occurrence_season = snapshot.occurrence_season
      obj.is_reference = snapshot.is_reference
      obj.region = snapshot.region
      obj.user_id = snapshot.user_id
      obj.instance_variable_set(:@associated_crop_ids, snapshot.associated_crop_ids)
      obj.instance_variable_set(
        :@pest_temperature_profile,
        PestTemperatureProfileMasterForm.from_attrs(snapshot.pest_temperature_profile_attributes)
      )
      obj.instance_variable_set(
        :@pest_thermal_requirement,
        PestThermalRequirementMasterForm.from_attrs(snapshot.pest_thermal_requirement_attributes)
      )
      cm = (snapshot.pest_control_methods_attributes || {}).sort_by { |k, _| k.to_s.to_i }.map { |_, v| PestControlMethodMasterForm.from_attrs(v) }
      cm = [ PestControlMethodMasterForm.from_attrs({}) ] if cm.empty?
      obj.instance_variable_set(:@pest_control_methods, cm)
      snapshot.error_messages.each { |msg| obj.errors.add(:base, msg) }
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

    def crop_ids
      @associated_crop_ids
    end

    def pest_temperature_profile
      p = @pest_temperature_profile
      return nil unless p
      return nil if p.base_temperature.blank? && p.max_temperature.blank?

      p
    end

    def pest_thermal_requirement
      p = @pest_thermal_requirement
      return nil unless p
      return nil if p.required_gdd.blank? && p.first_generation_gdd.blank?

      p
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

    def apply_params_hash!(params_pest_hash)
      h = params_pest_hash.to_h.deep_symbolize_keys
      %i[name name_scientific family order description occurrence_season region].each do |k|
        send("#{k}=", h[k]) if h.key?(k)
      end
      self.is_reference = h[:is_reference] if h.key?(:is_reference)

      if h[:pest_temperature_profile_attributes].present?
        @pest_temperature_profile = PestTemperatureProfileMasterForm.from_attrs(
          h[:pest_temperature_profile_attributes].to_h.symbolize_keys
        )
      end

      if h[:pest_thermal_requirement_attributes].present?
        @pest_thermal_requirement = PestThermalRequirementMasterForm.from_attrs(
          h[:pest_thermal_requirement_attributes].to_h.symbolize_keys
        )
      end

      if h[:pest_control_methods_attributes].present?
        raw = h[:pest_control_methods_attributes]
        pairs =
          if raw.is_a?(Hash)
            raw.sort_by { |k, _| k.to_s.to_i }.map { |_, v| PestControlMethodMasterForm.from_attrs(v.is_a?(Hash) ? v : {}) }
          else
            []
          end
        @pest_control_methods = pairs
        @pest_control_methods = [ PestControlMethodMasterForm.from_attrs({}) ] if @pest_control_methods.empty?
      end
    end

    def to_ar_nested_attributes
      cm_hash = {}
      Array(@pest_control_methods).each_with_index do |cm, i|
        cm_hash[i.to_s] = cm.to_nested_attributes
      end

      h = {
        name: name,
        name_scientific: name_scientific,
        family: family,
        order: order,
        description: description,
        occurrence_season: occurrence_season,
        is_reference: Domain::Shared::TypeConverters::BooleanConverter.cast(is_reference),
        pest_temperature_profile_attributes: @pest_temperature_profile.to_nested_attributes,
        pest_thermal_requirement_attributes: @pest_thermal_requirement.to_nested_attributes,
        pest_control_methods_attributes: cm_hash
      }
      h[:region] = region
      h[:user_id] = user_id
      h
    end

    def reload_from_snapshot!(snapshot)
      fresh = self.class.from_snapshot(snapshot)
      %i[
        @id @_new_record @associated_crop_ids @created_at @updated_at @pest_temperature_profile @pest_thermal_requirement @pest_control_methods
        @name @name_scientific @family @order @description @occurrence_season @is_reference @region @user_id
      ].each do |iv|
        instance_variable_set(iv, fresh.instance_variable_get(iv))
      end
      errors.clear
      snapshot.error_messages.each { |msg| errors.add(:base, msg) }
      self
    end
  end
end
