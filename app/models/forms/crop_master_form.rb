# frozen_string_literal: true

module Forms
  class CropMasterForm
    include Forms::HtmlFormSupport

    attr_accessor :name, :variety, :region, :area_per_unit, :revenue_per_area, :is_reference, :groups, :user_id
    attr_reader :id

    def crop_stages
      @crop_stages ||= []
    end

    def self.model_name
      Domain::Shared::FormModelName.from_logical_name("Crop")
    end

    def self.from_snapshot(snapshot)
      obj = new
      obj.instance_variable_set(:@id, snapshot.id)
      obj.instance_variable_set(:@user_id, snapshot.user_id)
      obj.name = snapshot.name
      obj.variety = snapshot.variety
      obj.region = snapshot.region
      obj.groups = snapshot.groups || []
      obj.area_per_unit = snapshot.area_per_unit
      obj.revenue_per_area = snapshot.revenue_per_area
      obj.is_reference = snapshot.is_reference
      obj.instance_variable_set(:@crop_stages, (snapshot.crop_stages || []).map { |s| CropStageMasterForm.from_snapshot(s) })
      obj.instance_variable_set(:@_new_record, snapshot.new_record?)
      snapshot.error_messages.each { |msg| obj.errors.add(:base, msg) }
      obj
    end

    def id=(v)
      @id = v
    end

    def crop_stages=(stages)
      @crop_stages = stages
    end

    def persisted?
      !new_record?
    end

    def new_record?
      return @_new_record if defined?(@_new_record)

      @id.blank?
    end

    def reference?
      Domain::Shared::TypeConverters::BooleanConverter.cast(is_reference)
    end

    def is_reference?
      reference?
    end

    def to_param
      id.to_s
    end

    def to_ar_assign_attributes
      h = {
        name: name,
        variety: variety,
        area_per_unit: area_per_unit,
        revenue_per_area: revenue_per_area,
        region: region,
        is_reference: Domain::Shared::TypeConverters::BooleanConverter.cast(is_reference),
        groups: normalized_groups,
        crop_stages_attributes: (crop_stages || []).map(&:to_nested_attributes)
      }
      h[:user_id] = user_id if user_id.present?
      h
    end

    private

    def normalized_groups
      g = groups
      return [] if g.blank?
      return g if g.is_a?(Array)

      g.to_s.split(",").map(&:strip).reject(&:blank?)
    end
  end
end
