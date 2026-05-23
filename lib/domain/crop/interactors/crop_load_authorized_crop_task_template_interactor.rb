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

        # @return [Domain::Crop::Dtos::AuthorizedCropTaskTemplateInCropContext, nil]
        def call(input)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(user)
          bundle = @gateway.find_crop_task_template_in_crop!(
            input.crop_id.to_i,
            input.template_id.to_i,
            for_edit: @for_edit
          )
          if @for_edit
            Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(access_filter, bundle.crop_entity)
          else
            Domain::Shared::ReferenceRecordAuthorization.assert_view_allowed!(access_filter, bundle.crop_entity)
          end
          bundle
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @failure_presenter.on_not_found(crop_id: input.crop_id.to_i)
          nil
        rescue Domain::Shared::Exceptions::RecordNotFound
          @failure_presenter.on_not_found(crop_id: input.crop_id.to_i)
          nil
        end
      end
    end
  end
end
