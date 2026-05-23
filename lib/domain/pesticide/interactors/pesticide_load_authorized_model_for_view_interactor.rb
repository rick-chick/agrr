# frozen_string_literal: true

module Domain
  module Pesticide
    module Interactors
      class PesticideLoadAuthorizedModelForViewInteractor
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(pesticide_id)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::PesticidePolicy.record_access_filter(user)
          bundle = @gateway.find_pesticide_loaded_bundle!(pesticide_id.to_i, for_edit: false)
          Domain::Shared::ReferenceRecordAuthorization.assert_view_allowed!(access_filter, bundle.pesticide_entity)
          html_display = Domain::Shared::Dtos::ResourceDisplayCapabilities.for_referencable_form(
            user,
            crop_is_reference: bundle.pesticide_entity.reference?,
            crop_user_id: bundle.pesticide_entity.user_id
          )
          enriched = Domain::Pesticide::Dtos::AuthorizedPesticideLoaded.new(
            pesticide_entity: bundle.pesticide_entity,
            master_form_snapshot: bundle.master_form_snapshot,
            html_display: html_display
          )
          @output_port.on_success(enriched)
        rescue Domain::Shared::Policies::PolicyPermissionDenied, Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure
        end
      end
    end
  end
end
