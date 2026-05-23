# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskUpdateFormSnapshotInteractor
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @user_id = user_id
          @gateway = gateway
          @user_lookup = user_lookup
        end

        def call(input)
          return if input.form_resubmit.blank?

          dto = input.form_resubmit[:dto]
          task_attributes = input.form_resubmit[:task_attributes]
          selected_crop_ids = input.form_resubmit[:selected_crop_ids]
          return if dto.nil?

          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::AgriculturalTaskPolicy.record_access_filter(user)
          current = @gateway.find_by_id(dto.id)
          Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(access_filter, current)
          task = @gateway.merge_update_form_snapshot_for_master_form!(
            user: user,
            task_id: dto.id,
            dto: dto,
            task_attributes: task_attributes
          )
          normalized_ids = Array(selected_crop_ids).map(&:to_i).uniq
          crop_cards =
            if input.accessible_crops
              Domain::Crop::Mappers::MasterFormCropSelectionCardsMapper.build(
                accessible_crops: input.accessible_crops,
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
