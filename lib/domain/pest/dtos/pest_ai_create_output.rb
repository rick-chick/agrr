# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      class PestAiCreateOutput
        attr_reader :http_status, :success, :pest_id, :pest_name, :name_scientific, :family,
                    :order, :description, :occurrence_season, :message

        def initialize(
          http_status:,
          pest_id:,
          pest_name:,
          name_scientific:,
          family:,
          order:,
          description:,
          occurrence_season:,
          message:
        )
          @http_status = http_status
          @success = true
          @pest_id = pest_id
          @pest_name = pest_name
          @name_scientific = name_scientific
          @family = family
          @order = order
          @description = description
          @occurrence_season = occurrence_season
          @message = message
        end
      end
    end
  end
end
