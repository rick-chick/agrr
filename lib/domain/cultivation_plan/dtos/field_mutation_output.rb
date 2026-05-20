# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # REST 圃場追加・削除の結果（`kind` で分岐）。
      class FieldMutationOutput
        attr_reader :kind, :plan_field_id, :field_name, :field_area, :total_area, :field_id, :message

        def initialize(kind:, plan_field_id: nil, field_name: nil, field_area: nil, total_area: nil, field_id: nil,
                       message: nil)
          @kind = kind
          @plan_field_id = plan_field_id
          @field_name = field_name
          @field_area = field_area
          @total_area = total_area
          @field_id = field_id
          @message = message
        end
      end
    end
  end
end
