# frozen_string_literal: true

class Crop < ApplicationRecord
  belongs_to :user, optional: true
  has_many :crop_stages, dependent: :destroy

  accepts_nested_attributes_for :crop_stages, allow_destroy: true, reject_if: :all_blank

  validates :name, presence: true
  validates :is_reference, inclusion: { in: [true, false] }

  scope :reference, -> { where(is_reference: true) }
  scope :user_owned, -> { where(is_reference: false) }
  scope :recent, -> { order(created_at: :desc) }
end


