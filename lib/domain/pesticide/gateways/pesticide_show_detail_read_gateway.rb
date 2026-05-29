# frozen_string_literal: true

module Domain
  module Pesticide
    module Gateways
      class PesticideShowDetailReadGateway
        # @return [Dtos::PesticideShowDetailSnapshot]
        def find_show_detail_snapshot(pesticide_id:)
          raise NotImplementedError, "Subclasses must implement find_show_detail_snapshot"
        end
      end
    end
  end
end
