# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Gateways
      class AgriculturalTaskShowDetailReadGateway
        # @return [Object] Dtos::AgriculturalTaskShowDetailSnapshot
        def find_show_detail_snapshot(task_id:)
          raise NotImplementedError, "Subclasses must implement find_show_detail_snapshot"
        end
      end
    end
  end
end
