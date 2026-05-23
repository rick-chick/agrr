# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      module PestMasterFormFailureBuilder
        CROP_BUNDLE_RESCUES = [
          Domain::Shared::Policies::PolicyPermissionDenied,
          Domain::Shared::Exceptions::RecordNotFound,
          Domain::Shared::Exceptions::RecordInvalid
        ].freeze

        private

        def pest_master_form_failure_for(user, input_dto, message:)
          payload, request_crop_ids = payload_and_crop_ids_for(input_dto, user_id: user.id)
          crop_selection_bundle =
            begin
              @gateway.pest_master_form_crop_selection_bundle!(
                user: user,
                master_edit_payload: payload,
                request_crop_ids: request_crop_ids
              )
            rescue *CROP_BUNDLE_RESCUES
              nil
            end

          Domain::Pest::Dtos::PestMasterFormFailure.new(
            message: message,
            master_edit_payload: payload,
            crop_selection_bundle: crop_selection_bundle
          )
        end

        def payload_and_crop_ids_for(input_dto, user_id:)
          case input_dto
          when Domain::Pest::Dtos::PestCreateInput
            [
              Domain::Pest::Mappers::PestMasterEditPayloadFromInputMapper.from_create_input(input_dto, user_id: user_id),
              Array(input_dto.crop_ids)
            ]
          when Domain::Pest::Dtos::PestUpdateInput
            request_crop_ids = input_dto.crop_ids.nil? ? [] : Array(input_dto.crop_ids)
            [
              Domain::Pest::Mappers::PestMasterEditPayloadFromInputMapper.from_update_input(input_dto, user_id: user_id),
              request_crop_ids
            ]
          else
            raise ArgumentError, "unsupported input_dto: #{input_dto.class}"
          end
        end
      end
    end
  end
end
