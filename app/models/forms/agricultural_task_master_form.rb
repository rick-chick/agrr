# frozen_string_literal: true

module Forms
  # 農作業マスタ HTML 用（ActiveRecord をビューに渡さない）。`form_with` の param キーは +agricultural_task+。
  #
  # @see Domain::AgriculturalTask::Dtos::AgriculturalTaskMasterFormSnapshot
  class AgriculturalTaskMasterForm
    include Forms::HtmlFormSupport

    attr_accessor :name, :description, :time_per_sqm, :weather_dependency, :required_tools, :skill_level, :region, :is_reference
    attr_reader :id

    # @return [Domain::Shared::FormModelName]
    def self.model_name
      Domain::Shared::FormModelName.from_logical_name("AgriculturalTask")
    end

    # @param snapshot [Domain::AgriculturalTask::Dtos::AgriculturalTaskMasterFormSnapshot]
    # @return [Forms::AgriculturalTaskMasterForm]
    def self.from_snapshot(snapshot)
      obj = new
      obj.instance_variable_set(:@id, snapshot.id)
      obj.name = snapshot.name
      obj.description = snapshot.description
      obj.time_per_sqm = snapshot.time_per_sqm
      obj.weather_dependency = snapshot.weather_dependency
      obj.required_tools = snapshot.required_tools || []
      obj.skill_level = snapshot.skill_level
      obj.region = snapshot.region
      obj.is_reference = snapshot.is_reference
      obj.instance_variable_set(:@_new_record, snapshot.new_record?)
      snapshot.error_messages.each { |msg| obj.errors.add(:base, msg) }
      obj
    end

    # @param v [Integer, nil]
    # @return [void]
    def id=(v)
      @id = v
    end

    # @return [Boolean]
    def persisted?
      !new_record?
    end

    # @return [Boolean]
    def new_record?
      return @_new_record if defined?(@_new_record)

      @id.blank?
    end

    # @return [Boolean]
    def is_reference?
      Domain::Shared::TypeConverters::BooleanConverter.cast(is_reference)
    end

    # @return [String]
    def to_param
      id.to_s
    end
  end
end
