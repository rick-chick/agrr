# frozen_string_literal: true

module Adapters
  module Fertilize
    # API ai_update が期待する call(fertilize_id, attrs) -> result インターフェースを提供。
    # 内部で FertilizeUpdateInteractor を使用する。
    # 依存はエッジ（Controller）から DI する。
    class FertilizeUpdateForAiAdapter
      Result = Struct.new(:success?, :data, :error, keyword_init: true)

      def initialize(user_id:, gateway:, translator:, user_lookup:)
        @user_id = user_id
        @gateway = gateway
        @translator = translator
        @user_lookup = user_lookup
      end

      def call(fertilize_id, attrs)
        output_port = CapturingOutputPort.new
        interactor = Domain::Fertilize::Interactors::FertilizeUpdateInteractor.new(output_port: output_port,
          gateway: @gateway,
          user_id: @user_id,
          translator: @translator, user_lookup: @user_lookup)
        input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInputDto.from_hash(attrs, fertilize_id)
        interactor.call(input_dto)
        output_port.result
      end

      private

      class CapturingOutputPort < Domain::Fertilize::Ports::FertilizeUpdateOutputPort
        attr_reader :result

        def on_success(fertilize_entity)
          @result = Result.new(success?: true, data: fertilize_entity, error: nil)
        end

        def on_failure(failure_dto)
          @result = Result.new(success?: false, data: nil, error: failure_dto.message)
        end
      end
    end
  end
end
