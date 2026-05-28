# frozen_string_literal: true

module Domain
  module Pesticide
    module Interactors
      class MastersCropPesticidesIndexInteractor
        def initialize(output_port:, user_id:, user_lookup:, pesticide_gateway:, crop_gateway:)
          @output_port = output_port
          @user_id = user_id
          @user_lookup = user_lookup
          @pesticide_gateway = pesticide_gateway
          @crop_gateway = crop_gateway
        end

        def call(crop_id:)
          user = @user_lookup.find(@user_id)
          crop_entity = @crop_gateway.find_by_id(crop_id)
          Domain::Crop::Policies::CropMastersNestedAccess.assert_edit_allowed_for_masters!(user, crop_entity)

          filter = Domain::Shared::Policies::PesticidePolicy.masters_crop_pesticides_index_filter(user)
          pesticides = @pesticide_gateway.list_by_crop_id_for_filter(crop_id: crop_entity.id, filter: filter)
          @output_port.on_success(pesticides)
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_not_found
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_not_found
        end
      end
    end
  end
end
