# frozen_string_literal: true

class PolicyPermissionDenied < StandardError; end

module ReferencableResourcePolicy
  extend ActiveSupport::Concern

  class_methods do
    # 管理者/一般ユーザーと is_reference / user_id に基づく一覧スコープ
    # モデル側で include して利用する想定。
    def visible_scope_for(user)
      if user.admin?
        where("is_reference = ? OR user_id = ?", true, user.id)
      else
        where(user_id: user.id, is_reference: false)
      end
    end
  end
end
