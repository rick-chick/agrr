# frozen_string_literal: true

# TaskScheduleItem の task_type 文字列（domain 側の単一ソース。AR モデルはここを参照する）
module Domain
  module AgriculturalTask
    module Constants
      module ScheduleItemTypes
        FIELD_WORK = "field_work"
        BASAL_FERTILIZATION = "basal_fertilization"
        TOPDRESS_FERTILIZATION = "topdress_fertilization"
      end
    end
  end
end
