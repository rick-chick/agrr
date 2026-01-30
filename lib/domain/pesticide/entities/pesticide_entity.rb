# frozen_string_literal: true

module Domain
  module Pesticide
    module Entities
      class PesticideEntity
        attr_reader :id, :user_id, :name, :active_ingredient, :description, :crop_id, :pest_id, :region, :is_reference, :created_at, :updated_at

        def initialize(id:, user_id:, name:, active_ingredient: nil, description: nil, crop_id: nil, pest_id: nil, region: nil, is_reference:, created_at:, updated_at:)
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

        def self.from_model(record)
          new(
            id: record.id,
            user_id: record.user_id,
            name: record.name,
            active_ingredient: record.active_ingredient,
            description: record.description,
            crop_id: record.crop_id,
            pest_id: record.pest_id,
            region: record.region,
            is_reference: record.is_reference,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end
      end
    end
  end
end
