# frozen_string_literal: true

module Domain
  module Pesticide
    module Dtos
      class PesticideUpdateInputDto
        attr_reader :pesticide_id, :name, :active_ingredient, :description, :crop_id, :pest_id, :region

        def initialize(pesticide_id:, name: nil, active_ingredient: nil, description: nil, crop_id: nil, pest_id: nil, region: nil)
          @pesticide_id = pesticide_id
          @name = name
          @active_ingredient = active_ingredient
          @description = description
          @crop_id = crop_id
          @pest_id = pest_id
          @region = region
        end

        def self.from_hash(hash, pesticide_id)
          pp = hash[:pesticide] || hash
          new(
            pesticide_id: pesticide_id,
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
