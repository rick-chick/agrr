# frozen_string_literal: true

module Domain
  module Crop
    module Exceptions
      # 作業スケジュールブループリント再生成時に作物に作業テンプレートが無い場合。
      class MissingTaskTemplatesForBlueprintRegeneration < StandardError
      end
    end
  end
end
