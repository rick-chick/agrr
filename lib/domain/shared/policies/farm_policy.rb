# frozen_string_literal: true

module Domain
  module Shared
    module Policies
      class FarmPolicy
        # HTML/JSON 双方から利用する、Farm の所有権ポリシー
        #
        # - ユーザー所有農場（is_reference: false, user_id = user.id）のみを「所有」とみなす
        # - 参照農場（is_reference: true）は PublicPlans 等で個別に利用

        # ユーザーにとって閲覧可能な Farm 一覧スコープ
        # Usage: FarmPolicy.visible_scope(Farm, user)
        def self.visible_scope(model_class, user)
          if user.admin?
            model_class.all
          else
            model_class.where("is_reference = ? OR user_id = ?", true, user.id)
          end
        end

        # ユーザー所有の農場スコープ
        # Usage: FarmPolicy.user_owned_scope(Farm, user)
        def self.user_owned_scope(model_class, user)
          model_class.user_owned.by_user(user)
        end

        # show 用の1件取得
        # - 管理者: すべての農場にアクセス可能
        # - 一般ユーザー: 参照農場 または 自分の農場
        def self.find_visible!(model_class, user, id)
          farm = model_class.find(id)
          unless user.admin? || farm.is_reference || farm.user_id == user.id
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          farm
        end

        # 所有する農場1件を取得（存在しない or 権限なし → PolicyPermissionDenied）
        #
        # - 一般ユーザー: 自分の user_owned 農場のみ
        # - 管理者: 既存の実装どおり、自分の農場 + 任意の農場にアクセス可能
        def self.find_owned!(model_class, user, id)
          farm = model_class.find(id)

          allowed =
            if user.admin?
              true
            else
              !farm.is_reference && farm.user_id == user.id
            end

          raise Domain::Shared::Policies::PolicyPermissionDenied unless allowed

          farm
        end

        # 編集・更新・削除用の1件取得
        # - 管理者: すべての農場を編集可能
        # - 一般ユーザー: 自分の非参照農場のみ
        def self.find_editable!(model_class, user, id)
          farm = model_class.find(id)
          allowed =
            if user.admin?
              true
            else
              !farm.is_reference && farm.user_id == user.id
            end

          raise Domain::Shared::Policies::PolicyPermissionDenied unless allowed
          farm
        end

        # create 用ビルダー
        # - HTML / Masters API ともに「ユーザー所有・非参照農場」を作成する前提
        def self.build_for_create(model_class, user, attrs)
          attributes = attrs.to_h.symbolize_keys

          attributes[:user_id] = user.id
          attributes[:is_reference] = false

          model_class.new(attributes)
        end

        # update 用適用メソッド
        def self.apply_update!(user, farm, attrs)
          attributes = attrs.to_h.symbolize_keys
          farm.update(attributes)
        end

        # 参照農場のスコープ（region でフィルタ可能）
        # Usage: FarmPolicy.reference_scope(Farm, region: 'jp')
        def self.reference_scope(model_class, region: nil)
          scope = model_class.reference
          scope = scope.where(region: region) if region
          scope
        end
      end
    end
  end
end