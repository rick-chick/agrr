# frozen_string_literal: true

module Forms
  # 作物ネストの CropTaskTemplate 編集 HTML 用（ActiveRecord をビューに渡さない）。
  class CropTaskTemplateEditForm
    include Forms::HtmlFormSupport

    attr_accessor :name, :description, :time_per_sqm, :weather_dependency, :skill_level
    attr_reader :id

    def self.model_name
      Domain::Shared::FormModelName.from_logical_name("CropTaskTemplate")
    end

    def self.from_dto(dto)
      obj = new
      obj.instance_variable_set(:@id, dto.id)
      obj.name = dto.name
      obj.description = dto.description
      obj.time_per_sqm = dto.time_per_sqm
      obj.weather_dependency = dto.weather_dependency
      obj.skill_level = dto.skill_level
      obj.instance_variable_set(:@required_tools, dto.required_tools || [])
      obj
    end

    def required_tools
      @required_tools || []
    end

    def required_tools=(v)
      @required_tools = v
    end

    def persisted?
      id.present?
    end

    def new_record?
      !persisted?
    end

    def id=(v)
      @id = v
    end

    def to_param
      id.to_s
    end
  end
end
