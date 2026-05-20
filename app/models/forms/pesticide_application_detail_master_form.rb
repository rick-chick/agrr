# frozen_string_literal: true

module Forms
  class PesticideApplicationDetailMasterForm
    include Forms::HtmlFormSupport

    attr_accessor :id, :dilution_ratio, :amount_per_m2, :amount_unit, :application_method, :_destroy

    def self.model_name
      Domain::Shared::FormModelName.from_logical_name("PesticideApplicationDetail")
    end

    def self.from_attrs(attrs)
      obj = new
      return obj if attrs.blank?

      h = attrs.symbolize_keys
      obj.id = h[:id].presence
      obj.dilution_ratio = h[:dilution_ratio]
      obj.amount_per_m2 = h[:amount_per_m2]
      obj.amount_unit = h[:amount_unit]
      obj.application_method = h[:application_method]
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
        dilution_ratio: dilution_ratio,
        amount_per_m2: amount_per_m2,
        amount_unit: amount_unit,
        application_method: application_method
      }
      h[:id] = id if id.present?
      h[:_destroy] = true if Domain::Shared::TypeConverters::BooleanConverter.cast(_destroy)
      h
    end
  end
end
