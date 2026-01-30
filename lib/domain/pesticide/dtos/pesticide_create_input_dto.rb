# frozen_string_literal: true

module Domain
  module Pesticide
    module Dtos
      class PesticideCreateInputDto
        attr_reader :name, :active_ingredient, :description, :crop_id, :pest_id, :region

        def initialize(name:, active_ingredient: nil, description: nil, crop_id: nil, pest_id: nil, region: nil)
          @name = name
          @active_ingredient = active_ingredient
          @description = description
          @crop_id = crop_id
          @pest_id = pest_id
          @region = region
        end

        def self.from_hash(hash)
          pp = hash[:pesticide] || hash
          new(
            name: pp[:name],
            active_ingredient: pp[:active_ingredient],
            description: pp[:description],
            crop_id: pp[:crop_id],
            pest_id: pp[:pest_id],
            region: pp[:region]
          )
        end
      end
    end
  end
end
