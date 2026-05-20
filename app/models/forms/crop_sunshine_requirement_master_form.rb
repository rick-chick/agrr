# frozen_string_literal: true

module Forms
  class CropSunshineRequirementMasterForm
    include Forms::HtmlFormSupport

    attr_accessor :minimum_sunshine_hours, :target_sunshine_hours, :_destroy
    attr_reader :id

    def self.model_name
      Domain::Shared::FormModelName.from_logical_name("SunshineRequirement")
    end

    def self.from_snapshot(snap)
      o = new
      o.instance_variable_set(:@id, snap.id)
      o.minimum_sunshine_hours = snap.minimum_sunshine_hours
      o.target_sunshine_hours = snap.target_sunshine_hours
      o._destroy = snap._destroy
      o
    end

    def id=(v)
      @id = v
    end

    def to_nested_attributes
      h = {
        minimum_sunshine_hours: minimum_sunshine_hours,
        target_sunshine_hours: target_sunshine_hours
      }
      h[:id] = id if id.present?
      h[:_destroy] = Domain::Shared::TypeConverters::BooleanConverter.cast(_destroy)
      h
    end
  end
end
