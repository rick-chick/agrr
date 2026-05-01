# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # プライベート計画ウィザード「農場選択」用の 1 農場分。ActiveRecord は含めない。
      class PrivatePlanNewFarmChoiceDto
        attr_reader :id, :display_name, :latitude, :longitude, :fields_count, :fields_total_area

        # @param id [Integer]
        # @param display_name [String]
        # @param latitude [Float]
        # @param longitude [Float]
        # @param fields_count [Integer]
        # @param fields_total_area [Float]
        def initialize(id:, display_name:, latitude:, longitude:, fields_count:, fields_total_area:)
          @id = id
          @display_name = display_name
          @latitude = latitude
          @longitude = longitude
          @fields_count = fields_count
          @fields_total_area = fields_total_area
        end

        def fields_present?
          @fields_count.positive?
        end
      end
    end
  end
end
