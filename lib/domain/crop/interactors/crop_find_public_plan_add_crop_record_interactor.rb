# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      # 公開栽培計画 REST: add_crop 用に参照作物レコードを解決する。
      class CropFindPublicPlanAddCropRecordInteractor
        def initialize(output_port:, gateway:, logger:)
          @output_port = output_port
          @gateway = gateway
          @logger = logger
        end

        def call(crop_id)
          crop = @gateway.find_reference_crop_record_for_public_plan_add_crop(crop_id)
          if crop
            @output_port.on_success(crop)
          else
            @logger.warn("[CropFindPublicPlanAddCropRecordInteractor] reference crop not found crop_id=#{crop_id.inspect}")
            @output_port.on_failure(Domain::Shared::Dtos::Error.new("Crop not found"))
          end
        end
      end
    end
  end
end
