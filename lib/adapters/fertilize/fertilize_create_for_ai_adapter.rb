# frozen_string_literal: true

module Adapters
  module Fertilize
    # API ai_create が期待する call(attrs) -> result インターフェースを提供。
    # 内部で FertilizeCreateInteractor を使用する。
    class FertilizeCreateForAiAdapter
      Result = Struct.new(:success?, :data, :error, keyword_init: true)

      def initialize(user_id:, gateway: nil)
        @user_id = user_id
        @gateway = gateway || Adapters::Fertilize::Gateways::FertilizeMemoryGateway.new
      end

      def call(attrs)
        output_port = CapturingOutputPort.new
        interactor = Domain::Fertilize::Interactors::FertilizeCreateInteractor.new(
          output_port: output_port,
          gateway: @gateway,
          user_id: @user_id
        )
        input_dto = Domain::Fertilize::Dtos::FertilizeCreateInputDto.from_hash(attrs)
        interactor.call(input_dto)
        output_port.result
      end

      private

      class CapturingOutputPort < Domain::Fertilize::Ports::FertilizeCreateOutputPort
        attr_reader :result

        def on_success(fertilize_entity)
          @result = Result.new(success?: true, data: fertilize_entity, error: nil)
        end

        def on_failure(error_dto)
          @result = Result.new(success?: false, data: nil, error: error_dto.message)
        end
      end
    end
  end
end
