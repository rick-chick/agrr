# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class AuthorizedCropLoaded
        attr_reader :crop_entity

        def initialize(crop_entity:)
          @crop_entity = crop_entity
        end
      end
    end
  end
end
