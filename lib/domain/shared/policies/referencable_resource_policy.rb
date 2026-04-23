# frozen_string_literal: true

module Domain
  module Shared
    module Policies
      # 参照可能リソース（is_reference / user_id）の可視性ルール。
      # ActiveRecord には触れない。Gateway が scope 構築に利用する。
      module ReferencableResourcePolicy
        module_function

        # 管理者: 参照データ OR 自分のデータ
        # 非管理者: 自分の非参照データのみ
        def visible_for_user?(user, is_reference:, user_id:)
          uid = user_id
          if user.admin?
            is_reference == true || uid == user.id
          else
            !is_reference && uid == user.id
          end
        end

        # 一覧用: 管理者は (is_reference OR user_id) / 一般は (user_id かつ非参照)
        def list_allowed_sql_params(user)
          if user.admin?
            { mode: :admin, user_id: user.id }
          else
            { mode: :non_admin, user_id: user.id }
          end
        end
      end
    end
  end
end
