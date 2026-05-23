# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class MastersCropPestsCreateInteractor
        def initialize(output_port:, user_id:, user_lookup:, pest_gateway:)
          @output_port = output_port
          @user_id = user_id
          @user_lookup = user_lookup
          @pest_gateway = pest_gateway
        end

        def call(crop_id, pest_id_raw)
          pest_id = pest_id_raw
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

          crop_access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(user)
          status = @pest_gateway.link_pest_to_crop(
            crop_id: crop_id,
            pest_id: pest_entity.id,
            user: user,
            crop_access_filter: crop_access_filter
          )
          case status
          when :missing
            @output_port.on_pest_not_found
          when :forbidden
            @output_port.on_forbidden
          when :already_linked
            @output_port.on_already_associated
          when :linked
            @output_port.on_success(crop_id: crop_id, pest_id: pest_entity.id)
          end
        end
      end
    end
  end
end
