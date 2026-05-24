# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # CropTaskScheduleBlueprint レコードの狭い CRUD。
      class CropTaskScheduleBlueprintGateway
        # @return [Array<Domain::CultivationPlan::Dtos::CropTaskScheduleBlueprintRow>]
        def list_by_crop_id(crop_id:)
          raise NotImplementedError
        end

        def delete_by_crop_id(crop_id:)
          raise NotImplementedError
        end

        # @param records [Array<Domain::CultivationPlan::Dtos::CropTaskScheduleBlueprintCreateAttrs>]
        def bulk_create(records:)
          raise NotImplementedError
        end
      end
    end
  end
end
