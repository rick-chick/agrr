# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      # 作業予定 API の永続化（検証・単位換算は domain）
      class TaskScheduleItemMutationActiveRecordGateway < Domain::CultivationPlan::Gateways::TaskScheduleItemMutationGateway
        def initialize(logger:)
          @logger = logger
        end

        def find_field_cultivation_for_create!(plan_id, field_cultivation_id)
          plan = cultivation_plan!(plan_id)
          field_cultivation = plan.field_cultivations.find(field_cultivation_id)
          crop_id = field_cultivation.cultivation_plan_crop&.crop_id
          Domain::CultivationPlan::Dtos::TaskScheduleFieldCultivationSnapshot.new(
            id: field_cultivation.id,
            cultivation_plan_crop_id: field_cultivation.cultivation_plan_crop_id,
            crop_id: crop_id
          )
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound
        end

        def find_crop_task_template_for_mutation(template_id)
          return nil if template_id.blank?

          record = ::CropTaskTemplate.includes(:agricultural_task, :crop).find(template_id)
          Domain::CultivationPlan::Dtos::TaskScheduleCropTaskTemplateSnapshot.new(
            id: record.id,
            crop_id: record.crop_id,
            name: record.name,
            description: record.description,
            task_type: record.task_type,
            weather_dependency: record.weather_dependency,
            time_per_sqm: record.time_per_sqm,
            agricultural_task_id: record.agricultural_task_id
          )
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound
        end

        def find_item_amount_snapshot!(plan_id, item_id)
          item = ar_item_for_plan(plan_id, item_id)
          raise Domain::Shared::Exceptions::RecordNotFound if item.nil?

          Domain::CultivationPlan::Dtos::TaskScheduleItemAmountSnapshot.new(
            amount: item.amount,
            amount_unit: item.amount_unit,
            scheduled_date: item.scheduled_date
          )
        end

        def create(plan_id:, attributes:)
          plan_id = plan_id.to_i
          attrs = attributes.to_h.symbolize_keys
          created = ::TaskScheduleItem.transaction do
            plan = cultivation_plan!(plan_id)
            field_cultivation = plan.field_cultivations.find(attrs[:field_cultivation_id])
            category = "general"

            schedule = field_cultivation.task_schedules.find_or_create_by!(
              category: category,
              cultivation_plan: plan
            ) do |record|
              record.status = TaskSchedule::STATUSES[:active]
              record.source = "manual_entry"
              record.generated_at = Time.zone.now
            end

            schedule.task_schedule_items.create!(
              attrs.except(:field_cultivation_id, :cultivation_plan_crop_id)
            )
          end
          serialize_item(created)
        rescue ActiveRecord::RecordInvalid => e
          raise_domain_record_invalid!(e.record, e.message)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound
        end

        def update_item_for_plan!(plan_id, item_id, attributes)
          plan_id = plan_id.to_i
          item = ar_item_for_plan(plan_id, item_id)
          raise Domain::Shared::Exceptions::RecordNotFound if item.nil?

          update_record_item!(item, attributes)
        end

        def complete_item_for_plan!(plan_id, item_id, actual_date:, actual_notes:, completed_at:)
          plan_id = plan_id.to_i
          item = ar_item_for_plan(plan_id, item_id)
          raise Domain::Shared::Exceptions::RecordNotFound if item.nil?

          complete_record_item!(item, actual_date: actual_date, actual_notes: actual_notes, completed_at: completed_at)
        end

        def deletion_undo_schedule_row_for_item!(plan_id, item_id)
          plan_id = plan_id.to_i
          item_id = item_id.to_i
          item = ar_item_for_plan(plan_id, item_id)
          raise Domain::Shared::Exceptions::RecordNotFound if item.nil?

          {
            resource_type: ::TaskScheduleItem.name,
            resource_id: item.id,
            item_name: item.name.to_s
          }.freeze
        end

        private

        def cultivation_plan!(plan_id)
          ::CultivationPlan.find(plan_id.to_i)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound
        end

        def ar_item_for_plan(plan_id, item_id)
          ::TaskScheduleItem
            .joins(task_schedule: :cultivation_plan)
            .where(
              task_schedules: { cultivation_plan_id: plan_id },
              cultivation_plans: { id: plan_id }
            )
            .find_by(id: item_id)
        end

        def update_record_item!(item, attributes)
          ::TaskScheduleItem.transaction do
            attrs = attributes.to_h.transform_keys(&:to_s)
            item.update!(attrs)
          end
          serialize_item(item.reload)
        rescue ActiveRecord::RecordInvalid => e
          raise_domain_record_invalid!(e.record, e.message)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound
        end

        def complete_record_item!(item, actual_date:, actual_notes:, completed_at:)
          ::TaskScheduleItem.transaction do
            item.update!(
              status: TaskScheduleItem::STATUSES[:completed],
              actual_date: actual_date,
              actual_notes: actual_notes,
              completed_at: completed_at
            )
          end
          serialize_item(item.reload)
        rescue ActiveRecord::RecordInvalid => e
          raise_domain_record_invalid!(e.record, e.message)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound
        end

        def serialize_item(item)
          {
            id: item.id,
            name: item.name,
            scheduled_date: item.scheduled_date&.iso8601,
            status: item.status,
            category: item.task_schedule.category
          }
        end

        def raise_domain_record_invalid!(record, message = nil)
          errors = record.errors.to_hash(true).transform_keys(&:to_s)
          errors.transform_values! { |messages| Array(messages).compact }
          msg = message || errors.values.flatten.compact.first
          raise Domain::Shared::Exceptions::RecordInvalid.new(msg, errors: errors)
        end
      end
    end
  end
end
