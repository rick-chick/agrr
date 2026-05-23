# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskLoadAuthorizedModelForViewInteractor
        def initialize(output_port:, user_id:, gateway:, logger:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @user_lookup = user_lookup
        end

        def call(task_id)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::AgriculturalTaskPolicy.record_access_filter(user)
          bundle = @gateway.find_agricultural_task_loaded_bundle!(task_id.to_i, for_edit: false)
          Domain::Shared::ReferenceRecordAuthorization.assert_view_allowed!(access_filter, bundle.agricultural_task_entity)
          html_display = Domain::Shared::Dtos::ResourceDisplayCapabilities.for_referencable_form(
            user,
            crop_is_reference: bundle.agricultural_task_entity.reference?,
            crop_user_id: bundle.agricultural_task_entity.user_id
          )
          enriched = Domain::AgriculturalTask::Dtos::AuthorizedAgriculturalTaskLoaded.new(
            agricultural_task_entity: bundle.agricultural_task_entity,
            master_form_snapshot: bundle.master_form_snapshot,
            html_display: html_display
          )
          @output_port.on_success(enriched)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @logger.warn("[AgriculturalTaskLoadAuthorizedModelForViewInteractor] #{e.message}")
          @output_port.on_failure(:no_permission)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @logger.warn("[AgriculturalTaskLoadAuthorizedModelForViewInteractor] #{e.message}")
          @output_port.on_failure(:not_found)
        end
      end
    end
  end
end
