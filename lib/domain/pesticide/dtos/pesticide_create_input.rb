# frozen_string_literal: true

module Domain
  module Pesticide
    module Dtos
      class PesticideCreateInput
        attr_reader :name, :active_ingredient, :description, :crop_id, :pest_id, :region, :is_reference,
                    :assign_attributes_for_form

        def initialize(name:, active_ingredient: nil, description: nil, crop_id: nil, pest_id: nil, region: nil, is_reference: nil,
                       assign_attributes_for_form: nil)
          @name = name
          @active_ingredient = active_ingredient
          @description = description
          @crop_id = crop_id
          @pest_id = pest_id
          @region = region
          @is_reference = is_reference
          @assign_attributes_for_form = assign_attributes_for_form
        end

        def self.from_hash(hash)
          pp = (hash[:pesticide] || hash).deep_symbolize_keys
          new(
            name: pp[:name],
            active_ingredient: pp[:active_ingredient],
            description: pp[:description],
            crop_id: pp[:crop_id],
            pest_id: pp[:pest_id],
            region: pp[:region],
            is_reference: pp[:is_reference],
            assign_attributes_for_form: pp
          )
        end
      end
    end
  end
end
