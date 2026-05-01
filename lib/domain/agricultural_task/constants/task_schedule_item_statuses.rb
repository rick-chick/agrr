# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Constants
      # TaskScheduleItem の status 値（モデル定数へのドメイン依存を避ける）
      module TaskScheduleItemStatuses
        PLANNED = "planned"
      end
    end
  end
end
