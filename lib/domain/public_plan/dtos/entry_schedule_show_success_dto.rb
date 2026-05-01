# frozen_string_literal: true

module Domain
  module PublicPlan
    module Dtos
      # 公開 entry_schedule/show の JSON（farm / prediction / crop）フラグメント。
      EntryScheduleShowSuccessDto = Struct.new(:farm_fragment, :prediction_fragment, :crop_fragment, keyword_init: true) do
        def to_h
          {
            farm: farm_fragment,
            prediction: prediction_fragment,
            crop: crop_fragment
          }
        end
      end
    end
  end
end
