# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      # 公開プラン保存: 圃場作成属性（座標→description 等、I/O なし）。
      class PlanSaveFieldCreateAttributesMapper
        # @param datum [Dtos::PublicPlanSaveFieldDatum]
        # @param translator [#t]
        # @return [Hash] :name, :area, :description (optional)
        def self.attributes_for_create(datum:, translator:)
          attrs = {
            name: datum.name,
            area: datum.area
          }

          coords = datum.coordinates
          if coords.is_a?(Array) && coords.length >= 2
            attrs[:description] = translator.t(
              "services.plan_save_service.messages.coordinates",
              lat: coords[0],
              lng: coords[1]
            )
          end

          attrs
        end
      end
    end
  end
end
