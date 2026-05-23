# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class MastersCropPestsCreateInteractor
        def initialize(output_port:, user_id:, user_lookup:, pest_gateway:, crop_gateway:)
          @output_port = output_port
          @user_id = user_id
          @user_lookup = user_lookup
          @pest_gateway = pest_gateway
          @crop_gateway = crop_gateway
        end

        def call(input)
          pest_id = input.pest_id_raw
          unless pest_id.present?
            return @output_port.on_pest_id_missing
          end

          pest_entity =
            begin
              @pest_gateway.find_by_id(pest_id)
            rescue Domain::Shared::Exceptions::RecordNotFound
              return @output_port.on_pest_not_found
            end

          user = @user_lookup.find(@user_id)

          unless @pest_gateway.pest_selectable_by_user?(user, pest_entity.id)
            return @output_port.on_forbidden
          end

          crop = @crop_gateway.find_by_id(input.crop_id)
          unless crop
            return @output_port.on_pest_not_found
          end
          Domain::Shared::Policies::CropNestedPestsAccess.assert_allowed!(user, crop)

          unless Domain::Shared::PestCropAssociationAccess.crop_accessible_for_pest?(crop, pest_entity, user: user)
            return @output_port.on_forbidden
          end

          if @pest_gateway.crop_pest_association_exists?(crop_id: input.crop_id, pest_id: pest_entity.id)
            return @output_port.on_already_associated
          end

          status = @pest_gateway.link_pest_to_crop(
            crop_id: input.crop_id,
            pest_id: pest_entity.id,
            user: user
          )
          case status
          when :missing
            @output_port.on_pest_not_found
          when :linked
            @output_port.on_success(crop_id: input.crop_id, pest_id: pest_entity.id)
          end
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_forbidden
        end
      end
    end
  end
end
