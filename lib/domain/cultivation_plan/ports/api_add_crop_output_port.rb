# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      class ApiAddCropOutputPort
        def on_success(plan_crop_id:, plan_crop_display_name:)
          raise NotImplementedError
        end

        def on_not_found
          raise NotImplementedError
        end

        def on_crop_not_found
          raise NotImplementedError
        end

        def on_prediction_incomplete(technical_details:)
          raise NotImplementedError
        end

        def on_no_candidates
          raise NotImplementedError
        end

        # @param adjust_payload [Hash] adjust_with_db_weather の戻り（success / message / status 等）
        def on_adjust_failed(adjust_payload:)
          raise NotImplementedError
        end

        def on_record_invalid(message:)
          raise NotImplementedError
        end

        def on_unexpected(message:)
          raise NotImplementedError
        end
      end
    end
  end
end
