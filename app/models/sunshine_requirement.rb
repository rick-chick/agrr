# frozen_string_literal: true

class SunshineRequirement < ApplicationRecord
  belongs_to :crop_stage

  validates :minimum_sunshine_hours, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :target_sunshine_hours, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
end


