# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class FarmUpdateInteractor < Domain::Farm::Ports::FarmUpdateInputPort
        def initialize(output_port:, user_id:, gateway:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(input_dto)
          user = @user_lookup.find(@user_id)
          attrs = {}
          attrs[:name] = input_dto.name unless input_dto.name.nil?
          attrs[:region] = input_dto.region if Domain::Shared.present?(input_dto.region)
          attrs[:latitude] = input_dto.latitude if !input_dto.latitude.nil?
          if !input_dto.longitude.nil?
            attrs[:longitude] = Domain::Farm::Policies::FarmCoordinateNormalizationPolicy.normalized_longitude(
              input_dto.longitude
            )
          end

          normalized = Domain::Shared::Policies::FarmPolicy.normalize_attrs_for_update(user, {}, attrs)
          access_filter = Domain::Shared::Policies::FarmPolicy.record_access_filter(user)
          current = @gateway.find_by_id(input_dto.farm_id)
          Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(access_filter, current)
          effective_reference = normalized.fetch(:is_reference, current.reference?)
          if effective_reference
            owner_id = normalized.fetch(:user_id, current.user_id)
            owner = @user_lookup.find(owner_id)
            unless Domain::Farm::Policies::FarmReferenceOwnershipPolicy.reference_farm_user_valid?(
              is_reference: true,
              owner_is_anonymous: owner.anonymous?
            )
              raise Domain::Shared::Exceptions::RecordInvalid.new(
                @translator.t("activerecord.errors.models.farm.attributes.is_reference.reference_only_anonymous")
              )
            end
          end
          if attrs.key?(:latitude) || attrs.key?(:longitude)
            lat = attrs.fetch(:latitude, current.latitude)
            lon = attrs.fetch(:longitude, current.longitude)
            if lat != current.latitude || lon != current.longitude
              normalized = normalized.merge(
                Domain::Farm::Calculators::FarmWeatherProgressCalculator.reset_for_coordinate_change_attrs
              )
            end
          end
          farm_entity = @gateway.update_for_user(user, input_dto.farm_id, normalized)

          @output_port.on_success(farm_entity)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
