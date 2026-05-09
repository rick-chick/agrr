# frozen_string_literal: true

module Domain
  module Fertilize
    module Interactors
      class FertilizeDetailInteractor < Domain::Fertilize::Ports::FertilizeDetailInputPort
        def initialize(output_port:, user_id:, gateway:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(fertilize_id)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::FertilizePolicy.record_access_filter(user)
          fertilize_entity = @gateway.find_authorized_for_view(user, fertilize_id, access_filter: access_filter)
          dto = Domain::Fertilize::Dtos::FertilizeDetailOutputDto.new(fertilize: fertilize_entity)
          @output_port.on_success(dto)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("fertilizes.flash.not_found")))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
