# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      class ApiPlanDataOutputPort
        # @param body [Hash] render json にそのまま渡すハッシュ（success, data, totals）
        def on_success(body:)
          raise NotImplementedError
        end

        def on_not_found
          raise NotImplementedError
        end

        def on_unexpected(message:)
          raise NotImplementedError
        end
      end
    end
  end
end
