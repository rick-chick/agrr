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

          pest_entity = @pest_gateway.find_by_id(pest_id) rescue nil
          unless pest_entity
            return @output_port.on_pest_not_found
          end

          user = @user_lookup.find(@user_id)

          unless @pest_gateway.pest_selectable_by_user?(user, pest_entity.id)
            return @output_port.on_forbidden
          end

          status = @pest_gateway.link_pest_to_crop_id(crop_id: crop_id, pest_id: pest_entity.id)
          case status
          when :missing
            @output_port.on_pest_not_found
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
