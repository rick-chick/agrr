# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class TaskScheduleItemCreateInteractor
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(user_id:, plan_id:, attributes:)
          attrs = Domain::Shared.symbolize_keys(attributes.to_h)
          field_cultivation = @gateway.find_field_cultivation_for_create!(
            user_id,
            plan_id,
            attrs[:field_cultivation_id]
          )
          template = @gateway.find_crop_task_template_for_mutation(attrs[:crop_task_template_id])

          Domain::CultivationPlan::Policies::TaskScheduleItemCreatePolicy.validate_crop_selection!(
            field_cultivation_crop_id: field_cultivation.cultivation_plan_crop_id,
            submitted_crop_id: attrs[:cultivation_plan_crop_id]
          )
          Domain::CultivationPlan::Policies::TaskScheduleItemCreatePolicy.validate_template!(
            field_crop_id: field_cultivation.crop_id,
            template: template
          )

          create_attrs = Domain::CultivationPlan::Policies::TaskScheduleItemCreatePolicy.build_create_attributes(
            attrs,
            template: template
          )
          @output_port.on_created(@gateway.create(user_id: user_id, plan_id: plan_id, attributes: create_attrs))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_record_invalid(
            errors: Domain::Shared::ValidationErrorHash.from(e.errors),
            fallback_message: e.message
          )
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_not_found
        end
      end
    end
  end
end
