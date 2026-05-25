# frozen_string_literal: true

class Field < ApplicationRecord
  # == Associations ========================================================
  belongs_to :farm
  belongs_to :user, optional: true
  # Note: FieldCultivationは cultivation_plan_field を通じて関連付けられています

  # == Validations =========================================================
  validates :name, presence: true, length: { maximum: 100 }
  validates :name, uniqueness: { scope: [ :user_id, :farm_id ], case_sensitive: false }
  validates :area, numericality: { greater_than: 0 }, allow_nil: true
  validates :daily_fixed_cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # == Instance Methods ====================================================

  def display_name
    name.presence || "##{id}"
  end
end
