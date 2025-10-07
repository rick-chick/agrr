# frozen_string_literal: true

class CropStage < ApplicationRecord
  belongs_to :crop
  has_one :temperature_requirement, dependent: :destroy
  has_one :sunshine_requirement, dependent: :destroy
  # has_one :thermal_requirement, dependent: :destroy  # Model doesn't exist yet

  validates :name, presence: true
  validates :order, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end


