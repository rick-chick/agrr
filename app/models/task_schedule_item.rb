# frozen_string_literal: true

class TaskScheduleItem < ApplicationRecord
  FIELD_WORK_TYPE = 'field_work'
  BASAL_FERTILIZATION_TYPE = 'basal_fertilization'
  TOPDRESS_FERTILIZATION_TYPE = 'topdress_fertilization'

  belongs_to :task_schedule

  validates :task_type, presence: true
  validates :name, presence: true
  validates :source, presence: true

  delegate :cultivation_plan, to: :task_schedule
  delegate :field_cultivation, to: :task_schedule
end

