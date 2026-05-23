# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropLoadAuthorizedInput
        attr_reader :crop_id, :for_edit

        def initialize(crop_id:, for_edit:)
          @crop_id = crop_id
          @for_edit = for_edit
        end
      end
    end
  end
end
