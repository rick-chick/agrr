# frozen_string_literal: true

class CropTaskScheduleBlueprint < ApplicationRecord
  TASK_TYPES = [
    TaskScheduleItem::FIELD_WORK_TYPE,
    TaskScheduleItem::BASAL_FERTILIZATION_TYPE,
    TaskScheduleItem::TOPDRESS_FERTILIZATION_TYPE
  ].freeze

  belongs_to :crop
  belongs_to :agricultural_task, optional: true

  validates :stage_order, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :gdd_trigger, presence: true, numericality: true
  validates :gdd_tolerance, numericality: true, allow_nil: true
  validates :task_type, presence: true, inclusion: { in: TASK_TYPES }
  validates :source, presence: true, inclusion: { in: TaskScheduleItem::AGRR_SOURCES }
  validates :priority, presence: true, numericality: { only_integer: true }
  validates :time_per_sqm, numericality: true, allow_nil: true
  validates :amount, numericality: true, allow_nil: true
  validates :agricultural_task_id,
            uniqueness: { scope: [:crop_id, :stage_order], allow_nil: true }

  scope :ordered, -> { order(:stage_order, :priority, :id) }
end
