# frozen_string_literal: true

module Forms
  class CropNutrientRequirementMasterForm
    include Forms::HtmlFormSupport

    attr_accessor :daily_uptake_n, :daily_uptake_p, :daily_uptake_k, :region, :_destroy
    attr_reader :id

    def self.model_name
      Domain::Shared::FormModelName.from_logical_name("NutrientRequirement")
    end

    def self.from_snapshot(snap)
      o = new
      o.instance_variable_set(:@id, snap.id)
      o.daily_uptake_n = snap.daily_uptake_n
      o.daily_uptake_p = snap.daily_uptake_p
      o.daily_uptake_k = snap.daily_uptake_k
      o.region = snap.region
      o._destroy = snap._destroy
      o
    end

    def id=(v)
      @id = v
    end

    def persisted?
      id.present?
    end

    def new_record?
      !persisted?
    end

    def to_nested_attributes
      h = {
        daily_uptake_n: daily_uptake_n,
        daily_uptake_p: daily_uptake_p,
        daily_uptake_k: daily_uptake_k,
        region: region
      }
      h[:id] = id if id.present?
      h[:_destroy] = Domain::Shared::TypeConverters::BooleanConverter.cast(_destroy)
      h
    end
  end
end
