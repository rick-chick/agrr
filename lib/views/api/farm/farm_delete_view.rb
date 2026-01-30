# frozen_string_literal: true

module Views
  module Api
    module Farm
      # View の契約。Controller がこのメソッドを実装する。
      # 実装は controller.render への委譲のみ: render(json: json, status: status)
      # undo_deletion_path は API 用 JSON の undo_path 組み立てに使用する。
      module FarmDeleteView
        def render_response(json:, status:)
          raise NotImplementedError, "#{self.class}#render_response"
        end

        def undo_deletion_path(undo_token:)
          raise NotImplementedError, "#{self.class}#undo_deletion_path"
        end
      end
    end
  end
end