# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Gateways
      class TaskScheduleGateway
        class << self
          def default
            @default ||= Adapters::AgriculturalTask::Gateways::TaskScheduleActiveRecordGateway.new
          end

          attr_writer :default

          def default_reset!
            @default = nil
          end
        end

        def delete_all_for_field_category(cultivation_plan_id:, field_cultivation_id:, category:)
          raise NotImplementedError, "Subclasses must implement delete_all_for_field_category"
        end

        # @return [Boolean]
        def replace_schedule_for_field_category!(cultivation_plan_id:, field_cultivation_id:, category:, generated_at:, items:)
          raise NotImplementedError, "Subclasses must implement replace_schedule_for_field_category!"
        end
      end
    end
  end
end
