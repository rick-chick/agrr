# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class CropsNestedPestsLoadPestInteractor
        def initialize(output_port:, user_id:, user_lookup:, pest_gateway:)
          @output_port = output_port
          @user_id = user_id
          @user_lookup = user_lookup
          @pest_gateway = pest_gateway
        end

        def call(crop_id:, pest_id:, for_edit_form: false)
          user = @user_lookup.find(@user_id)
          crop = @pest_gateway.find_crop_entity_by_id(crop_id)
          unless crop
            return @output_port.on_not_found(crop_id: crop_id)
          end
          Domain::Shared::Policies::CropNestedPestsAccess.assert_allowed!(user, crop)

          result = @pest_gateway.find_pest_in_crop(
            crop_id: crop_id,
            pest_id: pest_id,
            for_edit_form: for_edit_form
          )
          if result.status == :found
            @output_port.on_success(result.crop_nest_snapshot)
          else
            @output_port.on_not_found(crop_id: crop_id)
          end
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_not_found(crop_id: crop_id)
        end
      end
    end
  end
end
