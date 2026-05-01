# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class CropsNestedPestsCreateInteractor
        def initialize(output_port:, user_id:, user_lookup:, pest_gateway:)
          @output_port = output_port
          @user_id = user_id
          @user_lookup = user_lookup
          @pest_gateway = pest_gateway
        end

        # @param crop [Crop]    既存呼び出し互換のため AR を受け入れるが、本 Interactor は id のみ参照する。
        # @param link_pest_id [String,nil] params[:pest_id]
        # @param pest_attrs [Hash] Pest.new に渡す属性（permited）
        # @param admin [Boolean]
        def call(crop:, link_pest_id:, pest_attrs:, admin:)
          user = @user_lookup.find(@user_id)
          crop_id = crop.respond_to?(:id) ? crop.id : crop

          if link_pest_id.present?
            status = @pest_gateway.link_pest_to_crop_id(crop_id: crop_id, pest_id: link_pest_id)
            case status
            when :already_linked then return @output_port.on_already_linked(crop)
            when :linked         then return @output_port.on_linked(crop)
            when :missing        then return @output_port.on_link_target_missing(crop)
            end
          end

          result = @pest_gateway.create_pest_for_crop(
            user: user,
            crop_id: crop_id,
            pest_attrs: pest_attrs,
            admin: admin
          )
          case result[:status]
          when :reference_only_admin
            @output_port.on_reference_only_admin(crop)
          when :created
            @output_port.on_created(crop, result[:pest_record])
          when :invalid
            @output_port.on_invalid(result[:pest_record], result[:unassociated_pest_entities])
          end
        end
      end
    end
  end
end
