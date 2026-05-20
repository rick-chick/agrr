# frozen_string_literal: true

module Forms
  class PestControlMethodMasterForm
    include Forms::HtmlFormSupport

    attr_accessor :id, :method_type, :method_name, :description, :timing_hint, :_destroy

    def self.model_name
      Domain::Shared::FormModelName.from_logical_name("PestControlMethod")
    end

    def self.from_attrs(attrs)
      obj = new
      return obj if attrs.blank?

      h = attrs.symbolize_keys
      obj.id = h[:id].presence
      obj.method_type = h[:method_type]
      obj.method_name = h[:method_name]
      obj.description = h[:description]
      obj.timing_hint = h[:timing_hint]
      obj._destroy = Domain::Shared::TypeConverters::BooleanConverter.cast(h[:_destroy])
      obj
    end

    def persisted?
      id.present?
    end

    def new_record?
      id.blank?
    end

    def marked_for_destruction?
      false
    end

    def to_nested_attributes
      h = {
        method_type: method_type,
        method_name: method_name,
        description: description,
        timing_hint: timing_hint
      }
      h[:id] = id if id.present?
      h[:_destroy] = true if Domain::Shared::TypeConverters::BooleanConverter.cast(_destroy)
      h
    end
  end
end
