# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class MastersCropPestsDestroyInteractor
        def initialize(output_port:, user_id:, user_lookup:, pest_gateway:)
          @output_port = output_port
          @user_id = user_id
          @user_lookup = user_lookup
          @pest_gateway = pest_gateway
        end

        def call(crop_id:, pest_id:)
          user = @user_lookup.find(@user_id)
          crop = @pest_gateway.find_crop_entity_by_id(crop_id)
          unless crop
            return @output_port.on_crop_not_found
          end
          Domain::Shared::Policies::CropNestedPestsAccess.assert_allowed!(user, crop)

          pest_entity =
            begin
              @pest_gateway.find_by_id(pest_id)
            rescue Domain::Shared::Exceptions::RecordNotFound
              return @output_port.on_pest_not_found
            end

          unless @pest_gateway.crop_pest_association_exists?(crop_id: crop_id, pest_id: pest_entity.id)
            return @output_port.on_not_associated
          end

          status = @pest_gateway.unlink_pest_from_crop(
            crop_id: crop_id,
            pest_id: pest_entity.id
          )

          case status
          when :ok
            @output_port.on_success
          when :crop_not_found
            @output_port.on_crop_not_found
          when :pest_not_found
            @output_port.on_pest_not_found
          else
            @output_port.on_unexpected(status)
          end
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_crop_not_found
        end
      end
    end
  end
end
