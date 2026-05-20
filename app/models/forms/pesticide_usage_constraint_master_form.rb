# frozen_string_literal: true

module Forms
  class PesticideUsageConstraintMasterForm
    include Forms::HtmlFormSupport

    attr_accessor :id, :min_temperature, :max_temperature, :max_wind_speed_m_s,
                  :max_application_count, :harvest_interval_days, :other_constraints, :_destroy

    def self.model_name
      Domain::Shared::FormModelName.from_logical_name("PesticideUsageConstraint")
    end

    def self.from_attrs(attrs)
      obj = new
      return obj if attrs.blank?

      h = attrs.symbolize_keys
      obj.id = h[:id].presence
      %i[min_temperature max_temperature max_wind_speed_m_s max_application_count harvest_interval_days other_constraints].each do |k|
        obj.send("#{k}=", h[k])
      end
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
        min_temperature: min_temperature,
        max_temperature: max_temperature,
        max_wind_speed_m_s: max_wind_speed_m_s,
        max_application_count: max_application_count,
        harvest_interval_days: harvest_interval_days,
        other_constraints: other_constraints
      }
      h[:id] = id if id.present?
      h[:_destroy] = true if Domain::Shared::TypeConverters::BooleanConverter.cast(_destroy)
      h
    end
  end
end
