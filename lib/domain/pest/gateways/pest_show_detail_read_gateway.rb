# frozen_string_literal: true

module Domain
  module Pest
    module Gateways
      class PestShowDetailReadGateway
        # @return [Object] Dtos::PestShowDetailSnapshot
        def find_show_detail_snapshot(pest_id:)
          raise NotImplementedError, "Subclasses must implement find_show_detail_snapshot"
        end
      end
    end
  end
end
