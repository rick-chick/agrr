# frozen_string_literal: true

module Domain
  module Shared
    module Policies
      module ReferencableResourcePolicy
        # 管理者/一般ユーザーと is_reference / user_id に基づく一覧スコープ
        # モデル側で include して利用する想定。
        def self.visible_scope_for(model_class, user)
          if user.admin?
            model_class.where("is_reference = ? OR user_id = ?", true, user.id)
          else
            model_class.where(user_id: user.id, is_reference: false)
          end
        end
      end
    end
  end
end