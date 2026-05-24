# frozen_string_literal: true

module Adapters
  module FieldCultivation
    module Gateways
      # FieldCultivation API 用の薄いファサード（認可コンテキスト・CRUD）。気象組立は Interactor + Mapper。
      class FieldCultivationClimateActiveRecordGateway < Domain::FieldCultivation::Gateways::FieldCultivationGateway
        def initialize(context_gateway:)
          @context_gateway = context_gateway
        end

        delegate :find_plan_access_context, :find_api_summary, :update_field_cultivation_schedule,
                 to: :@context_gateway
      end
    end
  end
end
