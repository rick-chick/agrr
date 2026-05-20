# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Sessions
      module PlanSaveSessionDataCoercion
        module_function

        def deep_plain_hash(obj)
          case obj
          when ActionController::Parameters
            obj.to_unsafe_h.transform_values { |v| deep_plain_hash(v) }
          when Hash
            obj.transform_values { |v| deep_plain_hash(v) }
          when Array
            obj.map { |v| deep_plain_hash(v) }
          else
            obj
          end
        end

        def session_payload_to_hash(params)
          deep_plain_hash(params)
        end
      end
    end
  end
end
