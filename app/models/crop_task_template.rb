# frozen_string_literal: true

class CropTaskTemplate < ApplicationRecord
  belongs_to :crop
  belongs_to :agricultural_task, optional: true

  serialize :required_tools, coder: JSON

  after_initialize do
    self.required_tools ||= []
  end

  validates :name, presence: true
  validates :time_per_sqm, numericality: { greater_than: 0, allow_nil: true }
  validates :crop, presence: true
  validates :source_agricultural_task_id,
            uniqueness: {
              scope: :crop_id,
              allow_nil: true
            }
  validates :agricultural_task_id,
            uniqueness: {
              scope: :crop_id,
              allow_nil: true
            }

  def to_agrr_format
    {
      'task_id' => agrr_task_id.to_s,
      'name' => name,
      'description' => description,
      'time_per_sqm' => time_per_sqm&.to_f,
      'weather_dependency' => weather_dependency,
      'required_tools' => required_tools || [],
      'skill_level' => skill_level
    }.compact
  end

  def self.to_agrr_format_array(templates)
    templates.map(&:to_agrr_format)
  end

  private

  def agrr_task_id
    source_agricultural_task_id || agricultural_task_id || id
  end
end

