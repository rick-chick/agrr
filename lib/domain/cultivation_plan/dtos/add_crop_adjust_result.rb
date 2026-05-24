# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # plan_allocation_adjust の add_crop 向け結果（レガシー Hash の代替）。
      class AddCropAdjustResult
        attr_reader :success, :message, :http_status, :skipped

        def initialize(success:, message: nil, http_status: nil, skipped: false)
          @success = !!success
          @message = message
          @http_status = http_status
          @skipped = !!skipped
          freeze
        end

        def success?
          @success
        end
      end
    end
  end
end
