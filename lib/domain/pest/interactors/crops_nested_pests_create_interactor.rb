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

        # @param crop_id [Integer]
        # @param link_pest_id [String,nil] params[:pest_id]
        # @param pest_attrs [Hash] Pest.new に渡す属性（permited）
        def call(crop_id:, link_pest_id:, pest_attrs:)
          user = @user_lookup.find(@user_id)
          crop_access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(user)

          if link_pest_id.present?
            status = @pest_gateway.link_pest_to_crop(
              crop_id: crop_id,
              pest_id: link_pest_id,
              user: user,
              crop_access_filter: crop_access_filter
            )
            case status
            when :already_linked then return @output_port.on_already_linked(crop_id: crop_id)
            when :linked         then return @output_port.on_linked(crop_id: crop_id)
            when :missing        then return @output_port.on_link_target_missing(crop_id: crop_id)
            end
          end

          raw = Domain::Shared.symbolize_keys(pest_attrs.to_h)
          wants_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(raw[:is_reference]) || false
          if wants_reference && !user.admin?
            return @output_port.on_reference_only_admin(crop_id: crop_id)
          end

          normalized_attrs = Domain::Shared::Policies::PestPolicy.normalize_attrs_for_create(user, pest_attrs)

          result = @pest_gateway.create_pest_for_crop(
            user: user,
            crop_id: crop_id,
            pest_attrs: normalized_attrs,
            crop_access_filter: crop_access_filter
          )
          case result.status
          when :created
            @output_port.on_created(crop_id: crop_id, pest_id: result.pest_entity.id)
          when :invalid
            @output_port.on_invalid(crop_id: crop_id, pest_snapshot: result.crop_nest_snapshot, unassociated_pest_entities: result.unassociated_pest_entities)
          end
        end
      end
    end
  end
end
