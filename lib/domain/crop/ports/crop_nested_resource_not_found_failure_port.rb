# frozen_string_literal: true

module Domain
  module Crop
    module Ports
      # HTML リダイレクト / JSON 404 など、チャネル非依存の「ネストリソース未検出」通知。
      module CropNestedResourceNotFoundFailurePort
        def on_not_found
          raise NotImplementedError, "#{self.class} must implement #on_not_found"
        end
      end
    end
  end
end
