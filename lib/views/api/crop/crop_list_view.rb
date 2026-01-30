# frozen_string_literal: true

module Views
  module Api
    module Crop
      # View の契約。Controller がこのメソッドを実装する。
      # 実装は controller.render への委譲のみ: render(json: json, status: status)
      module CropListView
        def render_response(json:, status:)
          raise NotImplementedError, "#{self.class}#render_response"
        end
      end
    end
  end
end
