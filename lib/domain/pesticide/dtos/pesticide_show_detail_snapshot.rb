# frozen_string_literal: true

module Domain
  module Pesticide
    module Dtos
      class PesticideShowDetailPesticideSnapshot
        attr_reader :id, :user_id, :name, :active_ingredient, :description, :crop_id,
                    :pest_id, :region, :is_reference, :created_at, :updated_at

        def initialize(id:, user_id:, name:, active_ingredient:, description:, crop_id:,
                       pest_id:, region:, is_reference:, created_at:, updated_at:)
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
          freeze
        end
      end

      class PesticideShowDetailSnapshot
        attr_reader :pesticide, :crop_name, :pest_name, :usage_constraint, :application_detail

        def initialize(pesticide:, crop_name:, pest_name:, usage_constraint:, application_detail:)
          @pesticide = pesticide
          @crop_name = crop_name
          @pest_name = pest_name
          @usage_constraint = usage_constraint
          @application_detail = application_detail
          freeze
        end
      end
    end
  end
end
