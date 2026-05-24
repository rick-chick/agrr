# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class FarmCreateInteractor < Domain::Farm::Ports::FarmCreateInputPort
        def initialize(output_port:, user_id:, gateway:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(input_dto)
          user = @user_lookup.find(@user_id)
          attrs = Domain::Shared::Policies::FarmPolicy.normalize_attrs_for_create(
            user,
            {
              name: input_dto.name,
              region: input_dto.region,
              latitude: input_dto.latitude,
              longitude: input_dto.longitude
            }
          )
          if attrs[:longitude]
            attrs[:longitude] = Domain::Farm::Policies::FarmCoordinateNormalizationPolicy.normalized_longitude(
              attrs[:longitude]
            )
          end
          existing_count = @gateway.count_user_owned_non_reference_farms(user_id: user.id)
          if Domain::Farm::Policies::FarmCreateLimitPolicy.limit_exceeded?(existing_non_reference_count: existing_count)
            msg = @translator.t("activerecord.errors.models.farm.attributes.user.farm_limit_exceeded")
            return @output_port.on_failure(
              Domain::Farm::Dtos::FarmCreateLimitExceededFailure.new(message: msg)
            )
          end

          farm_entity = @gateway.create_for_user(user, attrs)

          @output_port.on_success(farm_entity)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
