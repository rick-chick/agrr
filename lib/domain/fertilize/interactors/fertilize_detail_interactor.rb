# frozen_string_literal: true

module Domain
  module Fertilize
    module Interactors
      class FertilizeDetailInteractor < Domain::Fertilize::Ports::FertilizeDetailInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(fertilize_id)
          user = User.find(@user_id)
          fertilize_model = Domain::Shared::Policies::FertilizePolicy.find_visible!(::Fertilize, user, fertilize_id)
          fertilize_entity = Domain::Fertilize::Entities::FertilizeEntity.from_model(fertilize_model)
          dto = Domain::Fertilize::Dtos::FertilizeDetailOutputDto.new(fertilize: fertilize_entity)
          @output_port.on_success(dto)
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
