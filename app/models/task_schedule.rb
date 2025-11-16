# frozen_string_literal: true

class TaskSchedule < ApplicationRecord
  CATEGORIES = %w[general fertilizer].freeze
  STATUSES = {
    active: 'active',
    archived: 'archived'
  }.freeze

  belongs_to :cultivation_plan
  belongs_to :field_cultivation, optional: true

  has_many :task_schedule_items, dependent: :delete_all

  validates :category, presence: true
  validates :status, presence: true
  validates :generated_at, presence: true

  validates :category, inclusion: { in: CATEGORIES }
  validates :status, inclusion: { in: STATUSES.values }

  scope :active, -> { where(status: STATUSES[:active]) }
end

