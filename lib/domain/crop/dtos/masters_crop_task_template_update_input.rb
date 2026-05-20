# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class MastersCropTaskTemplateUpdateInput
        attr_reader :user_id, :crop_id, :template_id, :attributes

        def initialize(user_id:, crop_id:, template_id:, attributes:)
          @user_id = user_id
          @crop_id = crop_id
          @template_id = template_id
          @attributes = attributes
        end
      end
    end
  end
end
