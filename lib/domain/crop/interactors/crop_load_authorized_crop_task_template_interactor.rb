# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropLoadAuthorizedCropTaskTemplateInteractor
        def initialize(failure_presenter:, user_id:, gateway:, user_lookup:, for_edit:)
          @failure_presenter = failure_presenter
          @user_id = user_id
          @gateway = gateway
          @user_lookup = user_lookup
          @for_edit = for_edit
        end

        # @return [Domain::Crop::Dtos::AuthorizedCropTaskTemplateInCropContextDto, nil]
        def call(crop_id, template_id)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(user)
          @gateway.find_authorized_crop_task_template_in_crop!(
            user,
            crop_id.to_i,
            template_id.to_i,
            for_edit: @for_edit,
            access_filter: access_filter
          )
        rescue Domain::Shared::Exceptions::RecordNotFound
          @failure_presenter.on_not_found
          nil
        end
      end
    end
  end
end
