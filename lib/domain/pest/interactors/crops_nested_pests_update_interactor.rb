# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class CropsNestedPestsUpdateInteractor
        def initialize(output_port:, pest_gateway:, user_id:, user_lookup:, crop_gateway:)
          @output_port = output_port
          @pest_gateway = pest_gateway
          @user_id = user_id
          @user_lookup = user_lookup
          @crop_gateway = crop_gateway
        end

        def call(crop_id:, pest_id:, pest_attrs:)
          user = @user_lookup.find(@user_id)
          crop = @crop_gateway.find_by_id(crop_id)
          unless crop
            return @output_port.on_not_found(crop_id: crop_id)
          end
          Domain::Shared::Policies::CropNestedPestsAccess.assert_allowed!(user, crop)

          found = @pest_gateway.find_pest_in_crop(
            crop_id: crop_id,
            pest_id: pest_id
          )
          unless found.status == :found
            return @output_port.on_not_found(crop_id: crop_id)
          end

           snapshot = found.crop_nest_snapshot
          requested = Domain::Shared.symbolize_keys(pest_attrs.to_h)

          if requested.key?(:is_reference)
            requested_ref = Domain::Shared::TypeConverters::BooleanConverter.cast(requested[:is_reference]) || false
            if requested_ref != snapshot.is_reference && !user.admin?
              return @output_port.on_reference_flag_denied(crop_id: crop_id, pest_id: snapshot.id)
            end
          end

          normalized = Domain::Shared::Policies::PestPolicy.normalize_attrs_for_update(
            user,
            { is_reference: snapshot.is_reference },
            requested
          )

          result = @pest_gateway.update_pest_for_crop(
            user: user,
            crop_id: crop_id,
            pest_id: pest_id,
            pest_attrs: normalized
          )

          case result.status
          when :updated
            @output_port.on_updated(crop_id: crop_id, pest_id: result.crop_nest_snapshot.id)
          when :invalid
            @output_port.on_invalid(crop_id: crop_id, pest_snapshot: result.crop_nest_snapshot)
          when :crop_missing, :pest_missing
            @output_port.on_not_found(crop_id: crop_id)
          end
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_not_found(crop_id: crop_id)
        end
      end
    end
  end
end
