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
  validates :agricultural_task_id,
            uniqueness: {
              scope: :crop_id,
              allow_nil: true
            }

  private
end
