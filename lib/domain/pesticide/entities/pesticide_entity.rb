# frozen_string_literal: true

module Domain
  module Pesticide
    module Entities
      class PesticideEntity
        attr_reader :id, :user_id, :name, :active_ingredient, :description, :crop_id, :pest_id, :region, :is_reference, :created_at, :updated_at

        def initialize(id:, user_id:, name:, active_ingredient: nil, description: nil, crop_id: nil, pest_id: nil, region: nil, is_reference:, created_at:, updated_at:)
          validate_region!(region)
          @id = id
          @user_id = user_id
          @name = name
          @active_ingredient = active_ingredient
          @description = description
          @crop_id = crop_id
          @pest_id = pest_id
          @region = region
          @is_reference = is_reference
          @created_at = created_at
          @updated_at = updated_at
        end

        def reference?
          !!is_reference
        end

        alias is_reference? reference?

        private

        def validate_region!(region)
          return if region.nil?

          valid_regions = %w[jp us in]
          unless valid_regions.include?(region)
            raise ArgumentError, "Region must be one of: #{valid_regions.join(', ')}"
          end
        end
      end
    end
  end
end
