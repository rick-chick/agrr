# frozen_string_literal: true

module Domain
  module Crop
    module Exceptions
      # AGRR 応答からブループリントを組み立てられない場合など。
      # アダプタは app 層サービスのメッセージをそのまま伝播する。
      class BlueprintRegenerationFromAgrrFailed < StandardError
      end
    end
  end
end
