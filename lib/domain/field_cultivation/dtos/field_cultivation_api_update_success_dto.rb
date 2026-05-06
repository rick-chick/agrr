# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      # API PATCH 成功ペイロード（private は message/cultivation_days なし、public はあり）
      class FieldCultivationApiUpdateSuccessDto
        attr_reader :field_cultivation_id, :start_date, :completion_date, :cultivation_days, :message

        def initialize(field_cultivation_id:, start_date:, completion_date:, cultivation_days: nil, message: nil)
          @field_cultivation_id = field_cultivation_id
          @start_date = start_date
          @completion_date = completion_date
          @cultivation_days = cultivation_days
          @message = message
        end

        def public_plan_response?
          !@message.nil?
        end
      end
    end
  end
end
