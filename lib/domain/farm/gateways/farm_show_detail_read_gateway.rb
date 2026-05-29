# frozen_string_literal: true

module Domain
  module Farm
    module Gateways
      class FarmShowDetailReadGateway
        # @return [Dtos::FarmShowDetailSnapshot]
        def find_show_detail_snapshot(farm_id:)
          raise NotImplementedError, "Subclasses must implement find_show_detail_snapshot"
        end
      end
    end
  end
end
