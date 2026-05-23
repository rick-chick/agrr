# frozen_string_literal: true

module Domain
  module Field
    module Interactors
      class FieldEditMasterFormInteractor
        def initialize(output_port:, user_id:, gateway:, farm_gateway:, user_lookup:)
          @output_port = output_port
          @user_id = user_id
          @gateway = gateway
          @farm_gateway = farm_gateway
          @user_lookup = user_lookup
        end

        def call(input)
          user = @user_lookup.find(@user_id)
          list = @gateway.farm_fields_list(input.farm_id.to_i)
          Domain::Field::Policies::FieldAccess.assert_field_edit_on_farm_allowed!(user, list.farm)
          Domain::Field::Policies::FieldAccess.assert_farm_fields_list_allowed!(user, list.farm)

          access_filter = Domain::Shared::Policies::FarmPolicy.record_access_filter(user)
          farm_bundle = @farm_gateway.find_farm_loaded_bundle!(input.farm_id.to_i, for_edit: true)
          Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(access_filter, farm_bundle.farm_entity)

          field_bundle = @gateway.find_field_loaded_in_farm!(input.farm_id.to_i, input.field_id.to_i)
          Domain::Field::Policies::FieldAccess.find_owned!(user, input.field_id.to_i)
          @output_port.on_success(
            farm_master_form_snapshot: farm_bundle.master_form_snapshot,
            field_master_form_snapshot: field_bundle.master_form_snapshot
          )
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_permission_denied(farm_id: input.farm_id)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_not_found(farm_id: input.farm_id)
        end
      end
    end
  end
end
