# frozen_string_literal: true

class ThermalRequirement < ApplicationRecord
  belongs_to :crop_stage

  validates :required_gdd, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
end

