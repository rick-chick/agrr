# frozen_string_literal: true

module Adapters
  module Pest
    # API ai_update が期待する call(pest_id, attrs) -> result インターフェースを提供。
    # 内部で PestUpdateInteractor を使用する。
    # 依存はエッジ（Controller）から DI する。
    class PestUpdateForAiAdapter
      Result = Struct.new(:success?, :data, :error, keyword_init: true)

      def initialize(user_id:, gateway:, logger:, translator:, user_lookup:)
        @user_id = user_id
        @gateway = gateway
        @logger = logger
        @translator = translator
        @user_lookup = user_lookup
      end

      def call(pest_id, attrs)
        output_port = CapturingOutputPort.new
        interactor = Domain::Pest::Interactors::PestUpdateInteractor.new(output_port: output_port,
          gateway: @gateway,
          user_id: @user_id, logger: @logger, translator: @translator, user_lookup: @user_lookup)
        input_dto = build_input_dto(pest_id, attrs)
        interactor.call(input_dto)
        output_port.result
      end

      private

      def build_input_dto(pest_id, attrs)
        dto_hash = api_attrs_to_dto_hash(attrs)
        Domain::Pest::Dtos::PestUpdateInputDto.from_hash(dto_hash, pest_id)
      end

      def api_attrs_to_dto_hash(attrs)
        h = attrs.to_h.symbolize_keys.slice(
          :name, :name_scientific, :family, :order, :description,
          :occurrence_season, :region, :is_reference
        )
        h[:pest_temperature_profile_attributes] = attrs[:temperature_profile] if attrs[:temperature_profile].present?
        h[:pest_thermal_requirement_attributes] = attrs[:thermal_requirement] if attrs[:thermal_requirement].present?
        h[:pest_control_methods_attributes] = attrs[:control_methods] if attrs[:control_methods].present?
        h
      end

      class CapturingOutputPort < Domain::Pest::Ports::PestUpdateOutputPort
        attr_reader :result

        def on_success(pest_entity)
          @result = Result.new(success?: true, data: pest_entity, error: nil)
        end

        def on_failure(failure_dto)
          @result = Result.new(success?: false, data: nil, error: failure_dto.message)
        end
      end
    end
  end
end
