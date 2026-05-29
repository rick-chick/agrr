# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropShowDetailPestSnapshot
        attr_reader :id, :user_id, :name, :name_scientific, :family, :order,
                    :description, :occurrence_season, :region, :is_reference,
                    :created_at, :updated_at

        def initialize(id:, user_id:, name:, name_scientific:, family:, order:,
                       description:, occurrence_season:, region:, is_reference:,
                       created_at:, updated_at:)
          @id = id
          @user_id = user_id
          @name = name
          @name_scientific = name_scientific
          @family = family
          @order = order
          @description = description
          @occurrence_season = occurrence_season
          @region = region
          @is_reference = is_reference
          @created_at = created_at
          @updated_at = updated_at
          freeze
        end
      end
    end
  end
end
