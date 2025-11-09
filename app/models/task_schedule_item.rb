# frozen_string_literal: true

class TaskScheduleItem < ApplicationRecord
  FIELD_WORK_TYPE = 'field_work'
  BASAL_FERTILIZATION_TYPE = 'basal_fertilization'
  TOPDRESS_FERTILIZATION_TYPE = 'topdress_fertilization'
  AGRR_SOURCES = %w[agrr agrr_schedule agrr_fertilize_plan copied_from_public_plan].freeze
  STATUSES = {
    planned: 'planned',
    rescheduled: 'rescheduled',
    completed: 'completed',
    cancelled: 'cancelled'
  }.freeze

  belongs_to :task_schedule
  belongs_to :agricultural_task, optional: true

  validates :task_type, presence: true
  validates :name, presence: true
  validates :source, presence: true
  validates :status, inclusion: { in: STATUSES.values }
  validate :gdd_presence_for_agrr_sources

  delegate :cultivation_plan, to: :task_schedule
  delegate :field_cultivation, to: :task_schedule

  private

  def gdd_presence_for_agrr_sources
    return unless source.in?(AGRR_SOURCES)

    errors.add(:gdd_trigger, 'must be present for AGRR由来の作業です') if gdd_trigger.nil?
  end
end

