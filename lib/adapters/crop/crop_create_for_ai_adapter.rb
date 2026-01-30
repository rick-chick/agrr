# frozen_string_literal: true

module Adapters
  module Crop
    # CropAiUpsertService が期待する call(attrs) -> result インターフェースを提供。
    # 内部で CropCreateInteractor を使用する。
    class CropCreateForAiAdapter
      Result = Struct.new(:success?, :data, :error, keyword_init: true)

      def initialize(user_id:, gateway: nil)
        @user_id = user_id
        @gateway = gateway || Adapters::Crop::Gateways::CropMemoryGateway.new
      end

      def call(attrs)
        output_port = CapturingOutputPort.new
        interactor = Domain::Crop::Interactors::CropCreateInteractor.new(
          output_port: output_port,
          gateway: @gateway,
          user_id: @user_id
        )
        input_dto = build_input_dto(attrs)
        interactor.call(input_dto)
        output_port.result
      end

      private

      def build_input_dto(attrs)
        Domain::Crop::Dtos::CropCreateInputDto.from_hash(attrs)
      end

      class CapturingOutputPort < Domain::Crop::Ports::CropCreateOutputPort
        attr_reader :result

        def on_success(crop_entity)
          @result = Result.new(success?: true, data: crop_entity, error: nil)
        end

        def on_failure(error_dto)
          @result = Result.new(success?: false, data: nil, error: error_dto.message)
        end
      end
    end
  end
end
