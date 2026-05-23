# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskHtmlUpdateFailureInteractor
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @user_id = user_id
          @gateway = gateway
          @user_lookup = user_lookup
        end

        # @param form_resubmit [Hash] :dto, :task_attributes, :selected_crop_ids
        # @param accessible_crops [Array] Crop AR（作物選択 UI 用）
        def call(form_resubmit, accessible_crops:)
          return if form_resubmit.blank?

          dto = form_resubmit[:dto]
          task_attributes = form_resubmit[:task_attributes]
          selected_crop_ids = form_resubmit[:selected_crop_ids]
          return if dto.nil?

          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::AgriculturalTaskPolicy.record_access_filter(user)
          task = @gateway.merge_update_form_snapshot_for_master_form!(
            user: user,
            task_id: dto.id,
            dto: dto,
            task_attributes: task_attributes,
            access_filter: access_filter
          )
          normalized_ids = Array(selected_crop_ids).map(&:to_i).uniq
          crop_cards =
            if accessible_crops
              Domain::AgriculturalTask::Mappers::EditFormCropSelectionCardsMapper.build(
                accessible_crops: accessible_crops,
                selected_ids: normalized_ids
              )
            else
              []
            end
          @output_port.on_apply(task_for_form: task, selected_crop_ids: normalized_ids, crop_cards: crop_cards)
        end
      end
    end
  end
end
