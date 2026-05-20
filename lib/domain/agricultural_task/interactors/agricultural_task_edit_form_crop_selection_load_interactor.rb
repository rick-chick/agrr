# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskEditFormCropSelectionLoadInteractor
        def initialize(
          output_port:,
          user_id:,
          agricultural_task_gateway:,
          crop_gateway:,
          user_lookup:,
          logger:
        )
          @output_port = output_port
          @user_id = user_id
          @agricultural_task_gateway = agricultural_task_gateway
          @crop_gateway = crop_gateway
          @user_lookup = user_lookup
          @logger = logger
        end

        def call(input_dto)
          user = @user_lookup.find(input_dto.user_id)
          access_filter = Domain::Shared::Policies::AgriculturalTaskPolicy.record_access_filter(user)
          base_entity = @agricultural_task_gateway.find_authorized_for_edit(
            user,
            input_dto.agricultural_task_id,
            access_filter: access_filter
          )
          preview_task =
            if input_dto.controller_action.to_s == "update"
              @agricultural_task_gateway.preview_agricultural_task_for_edit_crop_selection(
                base_entity: base_entity,
                user: user,
                agricultural_task_params: input_dto.agricultural_task_attributes_for_preview
              )
            else
              base_entity
            end

          accessible_crops =
            if preview_task.is_reference?
              @crop_gateway.list_reference_crop_entities(region: preview_task.region)
            else
              @crop_gateway.list_non_reference_crops_for_user_id_ordered(
                preview_task.user_id,
                preview_task.region
              )
            end

          accessible_crop_ids = accessible_crops.map(&:id)
          linked_ids =
            @agricultural_task_gateway
              .linked_crop_ids_for_task_templates(input_dto.agricultural_task_id)
              .map(&:to_i)
              .uniq

          raw = Array(input_dto.raw_selected_crop_ids).reject { |v| v.nil? || v.to_s.empty? }.map(&:to_i)
          filtered_selected = raw.select { |id| accessible_crop_ids.include?(id) }

          selected_for_cards =
            if input_dto.controller_action.to_s == "update" && raw.any?
              filtered_selected
            else
              linked_ids
            end

          selected_for_form_hidden = selected_for_cards

          crop_cards =
            if input_dto.include_crop_cards
              Domain::AgriculturalTask::Mappers::EditFormCropSelectionCardsMapper.build(
                accessible_crops: accessible_crops,
                selected_ids: selected_for_cards
              )
            else
              nil
            end

          @output_port.on_success(
            Domain::AgriculturalTask::Dtos::AgriculturalTaskEditFormCropSelectionOutput.new(
              accessible_crops: accessible_crops,
              accessible_crop_ids: accessible_crop_ids,
              filtered_selected_crop_ids: filtered_selected,
              selected_crop_ids_for_form_hidden: selected_for_form_hidden,
              crop_cards: crop_cards
            )
          )
          true
        end
      end
    end
  end
end
