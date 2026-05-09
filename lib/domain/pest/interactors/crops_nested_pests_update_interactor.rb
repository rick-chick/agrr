# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class CropsNestedPestsUpdateInteractor
        def initialize(output_port:, pest_gateway:, user_id:, user_lookup:)
          @output_port = output_port
          @pest_gateway = pest_gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(crop_id:, pest_id:, pest_attrs:)
          user = @user_lookup.find(@user_id)
          crop_access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(user)

          found = @pest_gateway.find_pest_in_crop(
            crop_id: crop_id,
            pest_id: pest_id,
            crop_access_filter: crop_access_filter
          )
          unless found[:status] == :found
            return @output_port.on_not_found(crop_id: crop_id)
          end

          pest = found[:pest_record]
          requested = pest_attrs.to_h.symbolize_keys

          if requested.key?(:is_reference)
            requested_ref = Domain::Shared::TypeConverters::BooleanConverter.cast(requested[:is_reference]) || false
            if requested_ref != pest.is_reference && !user.admin?
              return @output_port.on_reference_flag_denied(crop_id: crop_id, pest: pest)
            end
          end

          normalized = Domain::Shared::Policies::PestPolicy.normalize_attrs_for_update(
            user,
            pest.attributes.symbolize_keys,
            requested
          )

          result = @pest_gateway.update_pest_for_crop(
            user: user,
            crop_id: crop_id,
            pest_id: pest_id,
            pest_attrs: normalized,
            crop_access_filter: crop_access_filter
          )

          case result[:status]
          when :updated
            @output_port.on_updated(crop_id: crop_id, pest: result[:pest_record])
          when :invalid
            @output_port.on_invalid(crop_id: crop_id, pest: result[:pest_record])
          when :crop_missing, :pest_missing
            @output_port.on_not_found(crop_id: crop_id)
          end
        end
      end
    end
  end
end
