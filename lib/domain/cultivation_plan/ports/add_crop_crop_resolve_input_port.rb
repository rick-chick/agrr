# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      class AddCropCropResolveInputPort
        # @param auth [Domain::CultivationPlan::Dtos::CultivationPlanRestAuth]
        # @param crop_id [String, Integer]
        # @return [Object, nil] add_crop 用の作物エンティティ（見つからなければ nil）
        def call(auth:, crop_id:)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
