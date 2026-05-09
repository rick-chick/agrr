# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropMastersTaskTemplateDestroyInteractor
        def initialize(output_port:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_lookup = user_lookup
        end

        def call(input_dto)
          user = @user_lookup.find(input_dto.user_id)
          access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(user)
          @gateway.destroy_masters_crop_task_template_for_api!(
            user: user,
            crop_id: input_dto.crop_id,
            template_id: input_dto.template_id,
            access_filter: access_filter
          )
          @output_port.on_success
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure(
            Domain::Crop::Dtos::MastersCropTaskTemplateMastersFailureDto.new(reason: :association_not_found)
          )
        end
      end
    end
  end
end
