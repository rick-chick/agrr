# frozen_string_literal: true

module Domain
  module Pesticide
    module Interactors
      class PesticideDetailInteractor < Domain::Pesticide::Ports::PesticideDetailInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(pesticide_id)
          user = User.find(@user_id)
          pesticide_model = Domain::Shared::Policies::PesticidePolicy.find_visible!(::Pesticide, user, pesticide_id)
          pesticide_entity = Domain::Pesticide::Entities::PesticideEntity.from_model(pesticide_model)
          dto = Domain::Pesticide::Dtos::PesticideDetailOutputDto.new(pesticide: pesticide_entity)
          @output_port.on_success(dto)
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
