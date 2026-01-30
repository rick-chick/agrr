# frozen_string_literal: true

module Domain
  module Fertilize
    module Interactors
      class FertilizeListInteractor < Domain::Fertilize::Ports::FertilizeListInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(input_dto = nil)
          user = User.find(@user_id)
          fertilizes = @gateway.list
          visible_fertilizes = Domain::Shared::Policies::FertilizePolicy.visible_scope(::Fertilize, user)
          filtered_fertilizes = fertilizes.select { |fertilize_entity| visible_fertilizes.exists?(fertilize_entity.id) }
          @output_port.on_success(filtered_fertilizes)
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
