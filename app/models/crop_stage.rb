# frozen_string_literal: true

class CropStage < ApplicationRecord
  belongs_to :crop
  has_one :temperature_requirement, dependent: :destroy
  has_one :sunshine_requirement, dependent: :destroy
  has_one :thermal_requirement, dependent: :destroy
  has_one :nutrient_requirement, dependent: :destroy

  accepts_nested_attributes_for :temperature_requirement, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :sunshine_requirement, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :thermal_requirement, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :nutrient_requirement, allow_destroy: true, reject_if: :all_blank

  validates :name, presence: true
  validates :order, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end


