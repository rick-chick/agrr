# frozen_string_literal: true

module Domain
  module Pesticide
    module Dtos
      class PesticideUpdateInput
        attr_reader :pesticide_id, :name, :active_ingredient, :description, :crop_id, :pest_id, :region, :is_reference

        def initialize(pesticide_id:, name: nil, active_ingredient: nil, description: nil, crop_id: nil, pest_id: nil, region: nil, is_reference: nil)
          @pesticide_id = pesticide_id
          @name = name
          @active_ingredient = active_ingredient
          @description = description
          @crop_id = crop_id
          @pest_id = pest_id
          @region = region
          @is_reference = is_reference
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
            region: pp[:region],
            is_reference: pp[:is_reference]
          )
        end
      end
    end
  end
end
