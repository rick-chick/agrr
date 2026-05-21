# frozen_string_literal: true

module Adapters
  module AgriculturalTask
    module Presenters
      class AgriculturalTaskEditFormCropSelectionLoadHtmlPresenter < Domain::AgriculturalTask::Ports::AgriculturalTaskEditFormCropSelectionOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(dto)
          @view.instance_variable_set(:@accessible_crops, dto.accessible_crops)
          @view.instance_variable_set(:@accessible_crop_ids, dto.accessible_crop_ids)
          @view.instance_variable_set(:@filtered_selected_crop_ids_from_crop_selection_load, dto.filtered_selected_crop_ids)
          return if dto.crop_cards.nil?

          @view.instance_variable_set(:@crop_cards, dto.crop_cards)
          @view.instance_variable_set(:@selected_crop_ids, dto.selected_crop_ids_for_form_hidden)
        end
      end
    end
  end
end
