# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Dtos
      class AgriculturalTaskEditFormCropSelectionInputDto
        attr_reader :user_id, :agricultural_task_id, :controller_action,
                    :agricultural_task_attributes_for_preview, :raw_selected_crop_ids, :include_crop_cards

        def initialize(
          user_id:,
          agricultural_task_id:,
          controller_action:,
          agricultural_task_attributes_for_preview:,
          raw_selected_crop_ids: nil,
          include_crop_cards:
        )
          @user_id = user_id
          @agricultural_task_id = agricultural_task_id
          @controller_action = controller_action
          @agricultural_task_attributes_for_preview = agricultural_task_attributes_for_preview
          @raw_selected_crop_ids = raw_selected_crop_ids
          @include_crop_cards = include_crop_cards
        end
      end
    end
  end
end
